require_relative "test_helper"
require "csv"
require "date"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"

class ClassificationTest < Minitest::Test
  REPOSITORY = "https://github.com/example/project"
  PACKAGE_API = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages/example"

  def setup
    @directory = Dir.mktmpdir("classification-test")
    FileUtils.cp(%w[mydataset.rb package_writer.rb repos.rb commits.rb issues.rb classify.rb
                    advisories.rb report.rb http.rb database.rb lookup_failures.rb].map { |name|
      File.expand_path("../#{name}", __dir__)
    }, @directory)
    FileUtils.cp(File.expand_path("http_adapter.rb", __dir__), @directory)
    @db_path = File.join(@directory, "custom.db")
    @input = File.join(@directory, "input.csv")
    File.write(@input, "pkg:gem,example\n")
    @today = Date.today.iso8601
    @old = (Date.today - 366).iso8601
    @package = { "purl" => "pkg:gem/example", "name" => "example", "ecosystem" => "rubygems",
                 "repository_url" => REPOSITORY, "latest_release_published_at" => @old,
                 "repo_metadata" => { "archived" => false, "pushed_at" => @old } }
    import
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
  end

  def teardown
    @db&.close
    FileUtils.remove_entry(@directory)
  end

  def run_script(script, args = [], stubs = [])
    stub_path = File.join(@directory, "stubs.json")
    File.write(stub_path, JSON.generate(stubs))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @db_path, "HTTP_STUBS" => stub_path },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "http_adapter.rb"),
      File.join(@directory, script), *args
    )
    assert status.success?, output
    output
  end

  def import
    run_script("mydataset.rb", ["--refresh", @input], [["get", PACKAGE_API, 200, {}, JSON.generate(@package)]])
  end

  def collect(service, metadata)
    url = "https://#{service}.ecosyste.ms/api/v1/repositories/lookup?#{URI.encode_www_form(url: REPOSITORY)}"
    run_script("#{service}.rb", ["--refresh"], [["get", url, 200, {}, JSON.generate(metadata)]])
  end

  def classify
    run_script("classify.rb")
    @db.get_first_row("SELECT * FROM repos")
  end

  def test_stale_activity_is_preserved_but_cannot_establish_activity_or_nonresponse
    collect("commits", { "last_synced_at" => @old, "past_year_total_commits" => 15 })
    collect("issues", { "last_synced_at" => @old, "past_year_issues_count" => 1,
                        "past_year_issues_closed_count" => 0, "active_maintainers" => [] })
    row = classify
    assert_equal "unknown", row["bucket"]
    assert_equal 15, row["past_year_commits"]
    assert_equal 1, row["past_year_issues"]
    assert_includes row["signals"], "commits:stale"
    assert_includes row["signals"], "issues:stale"
    refute_includes row["signals"], "commits:15"

    collect("issues", { "last_synced_at" => @old, "active_maintainers" => [{ "login" => "maintainer" }],
                        "past_year_issues_closed_count" => 1, "past_year_merged_pull_requests_count" => 1 })
    assert_equal "unknown", classify["bucket"]
  end

  def test_commit_evidence_expires_after_one_year
    [365, 366].each do |age|
      collect("commits", { "last_synced_at" => (Date.today - age).iso8601, "past_year_total_commits" => 15 })
      assert_equal(age == 365 ? "active" : "unknown", classify["bucket"])
    end
  end

  def test_only_current_issue_evidence_can_establish_nonresponse
    metadata = { "last_synced_at" => @old, "past_year_issues_count" => 1, "active_maintainers" => [] }
    collect("issues", metadata)
    assert_equal "unknown", classify["bucket"]
    collect("issues", metadata.merge("last_synced_at" => @today))
    assert_equal "dead", classify["bucket"]
    collect("issues", metadata.merge("last_synced_at" => @today, "active_maintainers" => [{ "login" => "maintainer" }]))
    assert_equal "dormant", classify["bucket"]
  end

  def test_archive_status_requires_a_current_observation
    collect("repos", { "last_synced_at" => @old, "archived" => true })
    row = classify
    assert_equal "unknown", row["bucket"]
    assert_equal 1, row["archived"]
    assert_includes row["signals"], "repos:stale"
    collect("repos", { "last_synced_at" => @today, "archived" => true })
    assert_equal "dead", classify["bucket"]
  end

  def test_undated_invalid_and_future_observations_do_not_support_classification
    { nil => "missing", "" => "missing", "invalid" => "invalid", (Date.today + 1).iso8601 => "invalid" }.each do |timestamp, status|
      collect("repos", { "last_synced_at" => timestamp, "archived" => true })
      collect("commits", { "last_synced_at" => timestamp, "past_year_total_commits" => 15 })
      collect("issues", { "last_synced_at" => timestamp, "past_year_issues_count" => 1,
                          "active_maintainers" => [{ "login" => "maintainer" }] })
      row = classify
      assert_equal "unknown", row["bucket"]
      %w[repos commits issues].each { |source| assert_includes row["signals"], "#{source}:#{status}" }
    end
  end

  def test_recent_dated_events_remain_evidence_with_stale_service_observations
    @package["repo_metadata"]["pushed_at"] = @today
    import
    assert_equal "active", classify["bucket"]
    collect("repos", { "last_synced_at" => @old, "archived" => true, "pushed_at" => @old })
    @package["latest_release_published_at"] = @today
    import
    assert_equal "active", classify["bucket"]
  end

  def test_reports_include_evidence_dates_and_explain_unknown_results
    collect("repos", { "last_synced_at" => @old, "archived" => true })
    collect("issues", { "last_synced_at" => @old, "past_year_issues_count" => 1 })
    classify
    %w[situation eol_direct dead_transitive_count remediation alternative_purl remediation_notes
       remediation_source llm_confidence top1_dependent].each do |column|
      @db.execute("ALTER TABLE packages ADD COLUMN #{column}")
    end
    %w[code_loc complexity has_native].each { |column| @db.execute("ALTER TABLE repos ADD COLUMN #{column}") }
    url = "https://advisories.ecosyste.ms/api/v1/advisories?ecosystem=rubygems&package_name=example&per_page=100"
    run_script("advisories.rb", [], [["get", url, 200, {}, "[]"]])
    run_script("report.rb")
    csv = CSV.read(File.join(@directory, "custom.db.output/out/remediation.csv"), headers: true).first
    json = JSON.parse(File.read(File.join(@directory, "custom.db.output/out/remediation.json"))).first
    findings = CSV.read(File.join(@directory, "custom.db.output/findings/ruby.csv"), headers: true).first
    [csv, json, findings].each do |row|
      assert_equal "unknown", row["bucket"]
      assert_equal @old, row["repos_synced_at"]
      assert_equal @old, row["issues_synced_at"]
      assert_nil row["commits_synced_at"]
      refute_nil row["classified_at"]
      assert_includes row["signals"], "issues:stale"
    end
    assert_empty CSV.read(File.join(@directory, "custom.db.output/out/bernies.csv"), headers: true)
    collect("repos", { "last_synced_at" => @today, "archived" => true })
    classify
    run_script("report.rb")
    %w[bernies dead].each do |name|
      row = CSV.read(File.join(@directory, "custom.db.output/out/#{name}.csv"), headers: true).first
      assert_equal REPOSITORY, row["repository_url"]
      assert_equal @today, row["repos_synced_at"]
      assert_equal @old, row["issues_synced_at"]
      refute_nil row["classified_at"]
    end
  end
end
