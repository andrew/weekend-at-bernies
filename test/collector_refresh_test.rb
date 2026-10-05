require_relative "test_helper"
require "csv"
require "date"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"

class CollectorRefreshTest < Minitest::Test
  PACKAGE_API = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages"
  REPOS_API = "https://repos.ecosyste.ms/api/v1"
  COLLECTORS = %w[owners maintainers orgs emails clone deps dependents size].freeze

  def setup
    @directory = Dir.mktmpdir("collector-refresh-test")
    files = COLLECTORS.map { |name| "#{name}.rb" } + %w[mydataset.rb package_writer.rb http.rb database.rb
      lookup_failures.rb classify.rb situate.rb report.rb advisories.rb]
    FileUtils.cp(files.map { |name| File.expand_path("../#{name}", __dir__) }, @directory)
    FileUtils.cp(%w[http_adapter.rb collector_adapter.rb].map { |name| File.join(__dir__, name) }, @directory)
    @path = File.join(@directory, "bernies.db")
    @commands = File.join(@directory, "commands.jsonl")
    File.write(@commands, "")
    @today = Date.today.iso8601
    @old = (Date.today - 1000).iso8601
    @names = %w[alpha zeta]
    @owners = %w[a-example z-example]
    @urls = @owners.map { |owner| "https://github.com/#{owner}/project" }
    input = File.join(@directory, "input.csv")
    File.write(input, @names.map { |name| "pkg:gem,#{name}\n" }.join)
    packages = @names.each_with_index.map do |name, index|
      response("#{PACKAGE_API}/#{name}", {
        "purl" => "pkg:gem/#{name}", "name" => name, "ecosystem" => "rubygems",
        "repository_url" => @urls[index], "latest_release_number" => "1.0.0",
        "latest_release_published_at" => @old, "downloads" => 100, "dependent_packages_count" => index + 1,
        "repo_metadata" => { "pushed_at" => @old, "archived" => false }
      })
    end
    run_script("mydataset", [input], packages)
    @db = SQLite3::Database.new(@path)
    @db.results_as_hash = true
    @db.execute("UPDATE repos SET bucket='dead'")
  end

  def teardown
    @db&.close
    FileUtils.remove_entry(@directory)
  end

  def response(url, data, status = 200)
    ["get", url, status, {}, JSON.generate(data)]
  end

  def run_script(name, args = [], stubs = [], commands: {}, success: true)
    File.write(File.join(@directory, "stubs.json"), JSON.generate(stubs))
    File.write(File.join(@directory, "commands.json"), JSON.generate(commands))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @path, "HTTP_STUBS" => File.join(@directory, "stubs.json"),
        "COLLECTOR_STUBS" => File.join(@directory, "commands.json"), "COMMAND_LOG" => @commands },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "collector_adapter.rb"),
      File.join(@directory, "#{name}.rb"), *args
    )
    assert_equal success, status.success?, output
    output
  end

  def owner_responses(index, kind: "user", name: "Old")
    lookup = "#{REPOS_API}/repositories/lookup?#{URI.encode_www_form(url: @urls[index])}"
    owner = "#{REPOS_API}/hosts/GitHub/owners/#{@owners[index]}"
    [response(lookup, { "owner_url" => owner }), response(owner, { "login" => @owners[index], "kind" => kind, "name" => name })]
  end

  def populate_owners(kind = "user")
    run_script("owners", [], [*owner_responses(0, kind: kind), *owner_responses(1, kind: kind)])
  end

  def repo(index = 0)
    @db.get_first_row("SELECT * FROM repos WHERE repository_url=?", [@urls[index]])
  end

  def package(index = 0)
    @db.get_first_row("SELECT * FROM packages WHERE name=?", [@names[index]])
  end

  def test_owners_refresh_bypasses_embedded_and_api_caches_and_preserves_failed_results
    populate_owners
    cache = File.join(@directory, "cache/packages")
    FileUtils.mkdir_p(cache)
    File.write(File.join(cache, "old.json"), JSON.generate([{ "repo_metadata" => {
      "host" => { "url" => "https://github.com" }, "owner_record" => { "login" => @owners[0], "kind" => "user", "name" => "Embedded" }
    } }]))
    assert_includes run_script("owners"), "API fallback: 0"
    run_script("owners", ["--refresh", "1"], owner_responses(0, name: "Fresh"))
    assert_equal ["Fresh", "Old"], @db.execute("SELECT name FROM owners ORDER BY login").map { |row| row["name"] }
    run_script("owners")
    assert_equal "Fresh", @db.get_first_value("SELECT name FROM owners ORDER BY login")
    lookup = owner_responses(0).first[1]
    run_script("owners", ["1", "--refresh"], [response(lookup, nil, 404)])
    assert_equal "Fresh", @db.get_first_value("SELECT name FROM owners ORDER BY login")
    run_script("owners", [], owner_responses(0, name: "Recovered"))
    assert_equal "Recovered", @db.get_first_value("SELECT name FROM owners ORDER BY login")
  end

  def test_maintainers_and_orgs_refresh_both_sources_and_keep_the_failed_source
    [["maintainers", "user", "maintainers", "active_maintaining_count", "issues_synced"],
     ["orgs", "organization", "org_activity", "human_active_maintainer_count", "maintainers_synced"]].each do |script, kind, table, column, flag|
      @db.execute("UPDATE repos SET bucket='dead'")
      run_script("owners", ["--refresh"], [*owner_responses(0, kind: kind), *owner_responses(1, kind: kind)])
      run_script(script, [], activity_responses(script, 0, false) + activity_responses(script, 1, false))
      assert_includes run_script(script), "0 #{script == 'orgs' ? 'orgs' : 'maintainers'} to fetch"
      run_script(script, ["--refresh", "1"], activity_responses(script, 0, true))
      assert_equal [1, 0], @db.execute("SELECT #{column} FROM #{table} ORDER BY login").map { |row| row[column] }
      stubs = activity_responses(script, 0, true)
      stubs[0] = response(stubs[0][1], nil, 404)
      run_script(script, ["1", "--refresh"], stubs)
      row = @db.get_first_row("SELECT * FROM #{table} ORDER BY login")
      assert_equal 1, row[column]
      assert_equal 0, row[flag]
      assert_equal 1, row["repos_synced"]
      assert_equal @today, row["most_recent_push_at"]
    end
  end

  def activity_responses(script, index, fresh)
    login = @owners[index]
    if script == "maintainers"
      endpoint = "https://issues.ecosyste.ms/api/v1/hosts/GitHub/authors/#{login}"
      data = { "active_maintaining" => fresh ? [{ "repository" => @urls[index], "count" => 1 }] : [], "maintaining" => [] }
    else
      endpoint = "https://issues.ecosyste.ms/api/v1/hosts/GitHub/owners/#{login}/maintainers"
      list = fresh ? [{ "maintainer" => "person", "count" => 1 }] : []
      data = { "maintainers" => list, "active_maintainers" => list }
    end
    pushes = "#{REPOS_API}/hosts/GitHub/owners/#{login}/repositories?sort=pushed_at&order=desc&per_page=100"
    [response(endpoint, data), response(pushes, [{ "full_name" => "#{login}/project", "pushed_at" => fresh ? @today : @old }])]
  end

  def test_emails_refreshes_selected_users_and_domain_checks_without_erasing_failures
    populate_owners
    urls = @owners.map { |owner| "https://commits.ecosyste.ms/api/v1/hosts/GitHub/committers/#{owner}" }
    old = { "whois" => "Registry Expiry Date: 2020-01-01T00:00:00Z\n" }
    run_script("emails", [], [response(urls[0], { "emails" => ["old@example.test"] }), response(urls[1], { "emails" => ["other@gmail.com"] })], commands: old)
    assert_includes run_script("emails"), "fetch committer emails for 0 users"
    fresh = { "whois" => "Registry Expiry Date: 2040-01-01T00:00:00Z\n", "resolves" => false }
    run_script("emails", ["--refresh", "1"], [response(urls[0], { "emails" => ["new@example.test"] })], commands: fresh)
    assert_equal %w[new@example.test other@gmail.com], @db.execute("SELECT email FROM commit_emails ORDER BY email").map { |row| row["email"] }
    row = @db.get_first_row("SELECT * FROM email_domains WHERE domain='example.test'")
    assert_equal "active", row["whois_status"]
    assert_equal 0, row["resolves"]
    run_script("emails", ["--refresh", "1"], [response(urls[0], nil, 404)], commands: { "whois_failed" => true })
    assert_equal row, @db.get_first_row("SELECT * FROM email_domains WHERE domain='example.test'")
    assert_equal "new@example.test", @db.get_first_value("SELECT email FROM commit_emails WHERE login=?", [@owners[0]])
    run_script("emails", ["--refresh", "1"], [response(urls[0], { "emails" => ["new@example.test"] })], commands: fresh.merge("dns_failed" => true))
    assert_equal row, @db.get_first_row("SELECT * FROM email_domains WHERE domain='example.test'")
  end

  def dependency(name)
    { "ecosystem" => "rubygems", "package_name" => name, "kind" => "runtime", "requirements" => ">= 1.0.0", "direct" => true }
  end

  def test_dependency_refresh_replaces_edges_and_bypasses_database_latest_release_seed
    alpha = "#{PACKAGE_API}/alpha/versions/1.0.0"
    zeta = "#{PACKAGE_API}/zeta/versions/1.0.0"
    run_script("deps", [], [response(alpha, { "dependencies" => [dependency("removed"), dependency("zeta")] }),
                            response(zeta, { "dependencies" => [] }), response("#{PACKAGE_API}/removed", { "latest_release_number" => "1.0.0" })])
    assert_includes run_script("deps"), "0 packages to check"
    @db.execute("UPDATE packages SET deps_fetched_at='2000-01-01' WHERE name='zeta'")
    run_script("deps", ["--refresh", "1"], [response(alpha, { "dependencies" => [dependency("zeta")] }),
                                              response("#{PACKAGE_API}/zeta", { "latest_release_number" => "3.0.0" })])
    assert_equal ["zeta"], @db.execute("SELECT dep_name FROM dependencies").map { |row| row["dep_name"] }
    assert_equal 2, package["max_majors_behind"]
    assert_equal "2000-01-01", package(1)["deps_fetched_at"]
    saved = @db.execute("SELECT * FROM dependencies")
    run_script("deps", ["--refresh", "1"], [response(alpha, nil, 404)])
    assert_equal saved, @db.execute("SELECT * FROM dependencies")
    run_script("deps", ["--refresh", "1"], [response(alpha, { "dependencies" => [dependency("zeta")] }), response("#{PACKAGE_API}/zeta", nil, 404)])
    assert_equal saved, @db.execute("SELECT * FROM dependencies")
    run_script("deps", ["--refresh", "1"], [response(alpha, { "dependencies" => [] })])
    assert_empty @db.execute("SELECT * FROM dependencies")
    assert_equal 0, package["runtime_deps"]
  end

  def test_dependent_refresh_removes_old_ranks_and_preserves_failed_fetches
    urls = @names.map { |name| "#{PACKAGE_API}/#{name}/dependent_packages?per_page=20&sort=downloads" }
    list = [{ "name" => "old", "downloads" => 20 }, { "name" => "kept", "downloads" => 10 }]
    run_script("dependents", [], [response(urls[0], list), response(urls[1], [])])
    assert_includes run_script("dependents"), "0 packages to fetch"
    run_script("dependents", ["--refresh", "--ecosystem", "rubygems", "1"], [response(urls[0], [list.last])])
    assert_equal ["kept"], @db.execute("SELECT dependent_name FROM dependents").map { |row| row["dependent_name"] }
    assert_equal "kept", package["top1_dependent"]
    saved = @db.execute("SELECT * FROM dependents")
    run_script("dependents", ["--refresh", "1"], [response(urls[0], nil, 404)])
    assert_equal saved, @db.execute("SELECT * FROM dependents")
    run_script("dependents", ["--refresh", "1"], [response(urls[0], [])])
    assert_empty @db.execute("SELECT * FROM dependents")
    assert_nil package["top1_dependent"]
  end

  def test_clone_refresh_changes_classification_and_keeps_previous_data_after_failure
    run_script("clone", [], [], commands: { "last_commit_at" => @old })
    assert_includes run_script("clone"), "0 repos to shallow-clone"
    run_script("classify")
    assert_equal "unknown", repo["bucket"]
    run_script("clone", ["--refresh", "1"], [], commands: { "last_commit_at" => @today })
    assert_equal @today, repo["last_commit_at"]
    assert_equal @old, repo(1)["last_commit_at"]
    run_script("classify")
    assert_equal "dormant", repo["bucket"]
    before = repo
    run_script("clone", ["--refresh", "1"], [], commands: { "clone_failed" => true })
    assert_equal before, repo
  end

  def test_size_refresh_replaces_measurements_but_retains_them_when_clone_or_scc_fails
    run_script("size", [], [], commands: { "code_loc" => 10 })
    assert_includes run_script("size"), "0 repos to size"
    run_script("size", ["--refresh", "--ecosystem", "rubygems", "--bucket", "dead", "1"], [], commands: { "code_loc" => 500 })
    assert_equal 500, repo["code_loc"]
    assert_equal 10, repo(1)["code_loc"]
    before = repo
    [{ "clone_failed" => true }, { "scc_failed" => true }].each do |commands|
      run_script("size", ["--refresh", "1"], [], commands: commands)
      assert_equal before, repo
    end
  end

  def test_refresh_preserves_active_scope_unless_all_is_requested
    @db.execute("UPDATE repos SET bucket='active'")
    %w[clone size deps dependents].each do |script|
      assert_match(/0 (repos|packages) to/, run_script(script, ["--refresh", "1"]))
    end
    run_script("clone", ["--refresh", "--all", "1"], [], commands: { "last_commit_at" => @today })
    assert_equal @today, repo["last_commit_at"]
    assert_nil repo(1)["last_commit_at"]
  end

  def test_situate_recomputes_heuristics_preserves_human_values_and_rejects_refresh
    %w[deps dependents size].each { |script| run_script(script, ["0"]) }
    run_script("situate")
    @db.execute("UPDATE repos SET code_loc=10, complexity=1, has_native=0")
    @db.execute("UPDATE packages SET runtime_deps=0")
    @db.execute("UPDATE packages SET situation='broad', remediation_source='human' WHERE name='zeta'")
    run_script("situate")
    assert_equal "inlineable", package["situation"]
    assert_equal "broad", package(1)["situation"]
    assert_includes run_script("situate", ["--refresh"], [], success: false), "invalid option: --refresh"
  end

  def test_refreshed_measurements_reach_remediation_exports
    %w[deps dependents].each { |script| run_script(script, ["0"]) }
    run_script("size", [], [], commands: { "code_loc" => 500 })
    @db.execute("UPDATE packages SET runtime_deps=0")
    run_script("situate")
    stubs = @names.map do |name|
      response("https://advisories.ecosyste.ms/api/v1/advisories?ecosystem=rubygems&package_name=#{name}&per_page=100", [])
    end
    run_script("advisories", [], stubs)
    run_script("report")
    assert_equal "500", CSV.read(File.join(@directory, "out/remediation.csv"), headers: true).first["code_loc"]

    run_script("size", ["--refresh", "1"], [], commands: { "code_loc" => 10 })
    run_script("situate")
    run_script("report")
    csv = CSV.read(File.join(@directory, "out/remediation.csv"), headers: true).find { |row| row["name"] == "alpha" }
    json = JSON.parse(File.read(File.join(@directory, "out/remediation.json"))).find { |row| row["name"] == "alpha" }
    findings = CSV.read(File.join(@directory, "findings/ruby.csv"), headers: true).find { |row| row["name"] == "alpha" }
    [csv, json, findings].each do |row|
      assert_equal "10", row["code_loc"].to_s
      assert_equal "inlineable", row["situation"]
    end
  end

  def test_collectors_reject_unknown_options
    COLLECTORS.each do |script|
      assert_includes run_script(script, ["--not-an-option"], [], success: false), "invalid option: --not-an-option"
    end
  end
end
