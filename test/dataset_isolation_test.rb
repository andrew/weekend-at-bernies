require_relative "test_helper"
require "csv"
require "date"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"

class DatasetIsolationTest < Minitest::Test
  PACKAGES = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages"
  REPOS = "https://repos.ecosyste.ms/api/v1"

  def setup
    @directory = Dir.mktmpdir("dataset-isolation-test")
    FileUtils.cp(Dir[File.expand_path("../*.rb", __dir__)], @directory)
    FileUtils.cp(%w[http_adapter.rb collector_adapter.rb isolation_adapter.rb].map { |file| File.join(__dir__, file) }, @directory)
    @default = File.join(@directory, "bernies.db")
    @custom = File.join(@directory, "custom.db")
    @commands = File.join(@directory, "commands.jsonl")
    File.write(@commands, "")
    @today = Date.today.iso8601
    @old = (Date.today - 1000).iso8601
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def run_script(script, path, args = [], stubs: [], commands: {}, env: {})
    File.write(File.join(@directory, "stubs.json"), JSON.generate(stubs))
    File.write(File.join(@directory, "commands.json"), JSON.generate(commands))
    output, status = Open3.capture2e({
      "BERNIES_DB" => path == @default ? nil : path,
      "HTTP_STUBS" => File.join(@directory, "stubs.json"),
      "COLLECTOR_STUBS" => File.join(@directory, "commands.json"), "COMMAND_LOG" => @commands,
      "DOMAINR_CLIENT_ID" => "fixture", "RAPIDAPI_KEY" => nil
    }.merge(env), RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "isolation_adapter.rb"),
      File.join(@directory, "#{script}.rb"), *args)
    assert status.success?, output
    output
  end

  def response(url, data)
    ["get", url, 200, {}, JSON.generate(data)]
  end

  def query(path, sql, params = [])
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    db.execute(sql, params)
  ensure
    db&.close
  end

  def snapshot(path)
    query(path, "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name").to_h do |table|
      [table, query(path, "SELECT * FROM #{table['name']} ORDER BY rowid")]
    end
  end

  def files_snapshot
    Dir[File.join(@directory, "{out,findings}/**/*")].select { |path| File.file?(path) }.to_h do |path|
      [path, File.binread(path)]
    end
  end

  def populate(path, prefix, code_loc)
    owners = ["#{prefix}-user", "#{prefix}-org"]
    names = %w[example example-org]
    urls = owners.map { |owner| "https://github.com/#{owner}/project" }
    input = File.join(@directory, "input.csv")
    File.write(input, names.map { |name| "pkg:gem,#{name}\n" }.join)
    run_script("mydataset", path, ["--refresh", input], stubs: names.each_with_index.map { |name, i|
      response("#{PACKAGES}/#{name}", { "purl" => "pkg:gem/#{name}", "name" => name, "ecosystem" => "rubygems",
        "repository_url" => urls[i], "latest_release_number" => "1.0.0", "latest_release_published_at" => @old,
        "dependent_packages_count" => 300 })
    })
    %w[repos commits issues].each do |service|
      run_script(service, path, ["--refresh"], stubs: urls.map { |url|
        response("https://#{service}.ecosyste.ms/api/v1/repositories/lookup?#{URI.encode_www_form(url: url)}",
          { "last_synced_at" => @today, "archived" => true, "pushed_at" => @old })
      })
    end
    run_script("classify", path)
    run_script("clone", path, commands: { "last_commit_at" => @old })
    cache = File.join(@directory, "cache/packages")
    FileUtils.mkdir_p(cache)
    File.write(File.join(cache, "#{prefix}.json"), JSON.generate(owners.each_with_index.map { |owner, i|
      { "repo_metadata" => { "host" => { "url" => "https://GitHub.com" }, "owner_record" => {
        "login" => owner.upcase, "kind" => i.zero? ? "user" : "organization", "last_synced_at" => @today
      } } }
    }))
    run_script("owners", path)
    assert_equal owners.sort, query(path, "SELECT login FROM owners ORDER BY login").map { |row| row["login"] }
    run_script("maintainers", path, stubs: [
      response("https://issues.ecosyste.ms/api/v1/hosts/GitHub/authors/#{owners[0]}", { "active_maintaining" => [], "maintaining" => [] }),
      response("#{REPOS}/hosts/GitHub/owners/#{owners[0]}/repositories?sort=pushed_at&order=desc&per_page=100", [])
    ])
    run_script("orgs", path, stubs: [
      response("https://issues.ecosyste.ms/api/v1/hosts/GitHub/owners/#{owners[1]}/maintainers", { "maintainers" => [], "active_maintainers" => [] }),
      response("#{REPOS}/hosts/GitHub/owners/#{owners[1]}/repositories?sort=pushed_at&order=desc&per_page=100", [])
    ])
    run_script("emails", path, stubs: [response("https://commits.ecosyste.ms/api/v1/hosts/GitHub/committers/#{owners[0]}",
      { "emails" => ["person@#{prefix}.example.org"] })], commands: { "whois" => "unparseable" })
    run_script("deps", path, ["--refresh"], stubs: names.map { |name| response("#{PACKAGES}/#{name}/versions/1.0.0", { "dependencies" => [] }) })
    run_script("dependents", path, ["--refresh"], stubs: names.map { |name|
      response("#{PACKAGES}/#{name}/dependent_packages?per_page=20&sort=downloads", [])
    })
    run_script("size", path, commands: { "code_loc" => code_loc })
    run_script("advisories", path, ["--refresh"], stubs: names.map { |name|
      response("https://advisories.ecosyste.ms/api/v1/advisories?ecosystem=rubygems&package_name=#{name}&per_page=100", [])
    })
    run_script("classify", path)
    run_script("situate", path)
    run_script("tag", path)
    run_script("export_ecosystem", path, ["rubygems"])
    run_script("report", path)
    urls
  end

  def test_custom_pipeline_and_tag_import_preserve_default_database_and_exports
    populate(@default, "default", 10)
    before_db = snapshot(@default)
    before_files = files_snapshot
    urls = populate(@custom, "custom", 500)
    assert_equal before_db, snapshot(@default)
    assert_equal before_files, files_snapshot
    assert_equal ["custom-user"], query(@custom, "SELECT login FROM maintainers").map { |row| row["login"] }
    assert_equal ["custom-org"], query(@custom, "SELECT login FROM org_activity").map { |row| row["login"] }
    %w[out/remediation.csv out/tag.csv out/rubygems-bernies.csv findings/ruby.csv].each do |file|
      rows = CSV.read(File.join("#{@custom}.output", file), headers: true)
      assert_equal urls.sort, rows.map { |row| row["repository_url"] }.sort
    end
    tag_path = File.join("#{@custom}.output", "out/tag.csv")
    rows = CSV.read(tag_path, headers: true)
    rows.first["situation"] = "alternative"
    rows.first["remediation"] = "switch"
    File.write(tag_path, rows.to_csv)
    run_script("tag", @custom, ["--import", tag_path])
    assert_equal "human", query(@custom, "SELECT remediation_source FROM packages WHERE purl=?", [rows.first["purl"]]).first["remediation_source"]
    assert_equal "switch", query(@custom, "SELECT remediation FROM packages WHERE purl=?", [rows.first["purl"]]).first["remediation"]
    output = run_script("report", "custom.db")
    assert_includes output, "#{@custom}.output/out/remediation"
    assert_equal before_db, snapshot(@default)
    assert_equal before_files, files_snapshot
  end

  def test_domain_followups_use_custom_database
    populate(@default, "default", 10)
    populate(@custom, "custom", 500)
    before = snapshot(@default)
    run_script("domain_status", @custom, stubs: [response("https://api.domainr.com/v2/status?domain=custom.example.org&client_id=fixture",
      { "status" => [{ "status" => "active" }] })])
    assert_equal "active", query(@custom, "SELECT domainr_status FROM email_domains").first["domainr_status"]
    run_script("refetch_domain_status", @custom, stubs: [response("https://rdap.org/domain/custom.example.org",
      { "events" => [{ "eventAction" => "expiration", "eventDate" => "2040-01-01T00:00:00Z" }] })])
    assert_equal "active", query(@custom, "SELECT whois_status FROM email_domains").first["whois_status"]
    run_script("reparse_whois", @custom)
    assert_equal "unknown", query(@custom, "SELECT whois_status FROM email_domains").first["whois_status"]
    run_script("refetch_whois", @custom, commands: { "whois" => "Registry Expiry Date: 2040-01-01T00:00:00Z\n" })
    assert_equal "active", query(@custom, "SELECT whois_status FROM email_domains").first["whois_status"]
    assert_equal before, snapshot(@default)
  end

  def test_llm_cache_uses_current_evidence_and_model
    populate(@default, "default", 10)
    populate(@custom, "custom", 500)
    classify = lambda do |path, loc, situation, model = "fixture"|
      run_script("llm", path, commands: { "prompt_contains" => "\"code_loc\": #{loc}",
        "llm" => { "situation" => situation, "remediation" => "accept", "note" => "Fixture response", "confidence" => 0.9 }
      }, env: { "BERNIES_MODEL" => model })
    end
    classify.call(@default, 10, "inlineable")
    before = snapshot(@default)
    classify.call(@custom, 500, "broad")
    assert_equal ["broad"], query(@custom, "SELECT DISTINCT situation FROM packages").map { |row| row["situation"] }
    assert_equal before, snapshot(@default)
    calls = File.readlines(@commands).count { |line| JSON.parse(line).first == "claude" }
    assert_equal 4, calls
    classify.call(@custom, 500, "broad")
    assert_equal calls, File.readlines(@commands).count { |line| JSON.parse(line).first == "claude" }
    classify.call(@custom, 500, "broad", "alternate")
    assert_equal calls + 2, File.readlines(@commands).count { |line| JSON.parse(line).first == "claude" }
  end

  def test_science_report_preserves_default_paths_and_separates_custom_databases
    science = File.join(@directory, "science-bernies.db")
    run_script("fetch_science", science, ["1"], env: { "BERNIES_DB" => nil }, stubs: [
      ["get", "https://science.ecosyste.ms/projects?page=1", 200, {}, '<div id="project_42"><h3>Example</h3></div>'],
      response("https://science.ecosyste.ms/api/v1/projects/42", {
        "id" => 42, "name" => "Default science", "url" => "https://github.com/science/project"
      })
    ])
    run_script("report_science", science)
    default_path = File.join(@directory, "out/science-projects.csv")
    original = File.read(default_path)
    assert_equal "Default science", CSV.parse(original, headers: true).first["name"]
    %w[first second].each do |name|
      folder = File.join(@directory, name)
      FileUtils.mkdir_p(folder)
      custom = File.join(folder, "custom.db")
      query(science, "VACUUM INTO ?", [custom])
      query(custom, "UPDATE science_projects SET name=?", [name])
      output = run_script("report_science", custom)
      assert_includes output, "#{custom}.output/out/science-projects.csv"
    end
    %w[first second].each do |name|
      rows = CSV.read(File.join(@directory, name, "custom.db.output/out/science-projects.csv"), headers: true)
      assert_equal name, rows.first["name"]
    end
    assert_equal original, File.read(default_path)
  end
end
