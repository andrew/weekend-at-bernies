require_relative "test_helper"
require "csv"
require "date"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"

class LookupFailuresTest < Minitest::Test
  REPOSITORY = "https://github.com/example/project"
  LOOKUP = "https://repos.ecosyste.ms/api/v1/repositories/lookup?#{URI.encode_www_form(url: REPOSITORY)}"
  OWNER = "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/example"
  PACKAGE = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages/example"

  def setup
    @directory = Dir.mktmpdir("lookup-failures-test")
    FileUtils.cp(%w[mydataset.rb package_writer.rb database.rb lookup_failures.rb http.rb
                    repos.rb owners.rb classify.rb advisories.rb report.rb].map { |name|
      File.expand_path("../#{name}", __dir__)
    }, @directory)
    adapter = File.read(File.expand_path("http_adapter.rb", __dir__))
    File.write(File.join(@directory, "adapter.rb"), adapter + "\nmodule Kernel\n  def sleep(*)\n  end\nend\n")
    @path = File.join(@directory, "custom.db")
    @csv_path = File.join(@directory, "out", "failures.csv")
    @input = File.join(@directory, "input.csv")
    File.write(@input, "pkg:gem,example\n")
    @package = { "name" => "example", "purl" => "pkg:gem/example", "ecosystem" => "rubygems", "repository_url" => REPOSITORY }
    run_script("mydataset.rb", [@input], [response(PACKAGE, 200, @package)])
    @db = SQLite3::Database.new(@path)
    @db.results_as_hash = true
  end

  def teardown
    @db&.close
    FileUtils.remove_entry(@directory)
  end

  def response(url, status, data = nil, method: "get")
    [method, url, status, {}, JSON.generate(data)]
  end

  def run_script(script, args = [], stubs = [], success: true)
    stub_path = File.join(@directory, "stubs.json")
    File.write(stub_path, JSON.generate(stubs))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @path, "HTTP_STUBS" => stub_path },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "adapter.rb"),
      File.join(@directory, script), *args
    )
    assert_equal success, status.success?, output
    output
  end

  def repo_metadata
    { "full_name" => "example/project", "last_synced_at" => Date.today.iso8601,
      "archived" => false, "stargazers_count" => 123, "owner_url" => OWNER }
  end

  def failure
    @db.get_first_row("SELECT * FROM lookup_failures")
  end

  def test_repository_miss_records_both_statuses_and_package_identity
    output = run_script("repos.rb", ["--failures", @csv_path, "1"], [
      response(LOOKUP, 404), response(REPOSITORY, 404, method: "head")
    ])
    assert_includes output, "repository_not_found"
    assert_equal 404, failure["http_status"]
    assert_equal 404, failure["host_status"]
    assert_equal REPOSITORY, failure["identifier"]
    assert_equal LOOKUP, failure["endpoint"]
    row = CSV.read(@csv_path, headers: true).first
    assert_equal "pkg:gem/example", row["packages"]
    assert_equal "repository_not_found", row["reason"]
    assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")
    run_script("classify.rb")
    assert_equal "unknown", @db.get_first_value("SELECT bucket FROM repos")
    prepare_report
    run_script("report.rb")
    assert_equal "repository_not_found", CSV.read(File.join(@directory, "custom.db.output/out/lookup-failures.csv"), headers: true).first["reason"]

    run_script("repos.rb", ["--failures", @csv_path], [response(LOOKUP, 200, repo_metadata)])
    assert_empty @db.execute("SELECT * FROM lookup_failures")
    assert_empty CSV.read(@csv_path, headers: true)
    run_script("report.rb")
    assert_empty CSV.read(File.join(@directory, "custom.db.output/out/lookup-failures.csv"), headers: true)
  end

  def test_service_miss_is_distinct_from_an_unavailable_repository
    run_script("repos.rb", [], [response(LOOKUP, 404), response(REPOSITORY, 200, method: "head")])
    assert_equal "repository_service_miss", failure["reason"]
    assert_equal 200, failure["host_status"]
  end

  def test_failed_refresh_preserves_data_and_retries_without_refresh
    [429, 503].each do |status|
      run_script("repos.rb", ["--refresh"], [response(LOOKUP, 200, repo_metadata)])
      run_script("repos.rb", ["--refresh"], Array.new(5) { response(LOOKUP, status) })
      assert_equal status, failure["http_status"]
      assert_equal(status == 429 ? "rate_limited" : "server_error", failure["reason"])
      assert_equal 123, @db.get_first_value("SELECT stars FROM repos")
      assert_equal Date.today.iso8601, @db.get_first_value("SELECT repos_synced_at FROM repos")
      run_script("repos.rb", [], [response(LOOKUP, 200, repo_metadata.merge("stargazers_count" => 456))])
      assert_equal 456, @db.get_first_value("SELECT stars FROM repos")
      assert_empty @db.execute("SELECT * FROM lookup_failures")
    end
  end

  def test_legacy_null_cache_is_refetched_with_a_known_status
    cache = File.join(@directory, "cache/repos")
    FileUtils.mkdir_p(cache)
    key = Digest::SHA256.hexdigest(["https://repos.ecosyste.ms/", "/api/v1/repositories/lookup", { url: REPOSITORY }.sort].join("|"))[0, 32]
    File.write(File.join(cache, "#{key}.json"), "null")
    run_script("repos.rb", [], [response(LOOKUP, 403)])
    assert_equal "access_denied", failure["reason"]
    assert_equal 403, failure["http_status"]
    refute File.exist?(File.join(cache, "#{key}.json"))
  end

  def test_timeout_and_invalid_json_are_reported_without_a_false_404
    run_script("repos.rb", [], Array.new(5) { response(LOOKUP, "timeout") })
    assert_equal "timeout", failure["reason"]
    assert_nil failure["http_status"]
    run_script("repos.rb", [], [["get", LOOKUP, 200, {}, "invalid JSON"]])
    assert_equal "invalid_json", failure["reason"]
    assert_equal 200, failure["http_status"]
  end

  def test_owner_failure_identifies_the_owner_and_recovers_on_rerun
    output = run_script("owners.rb", ["--failures", @csv_path], [
      response(LOOKUP, 200, repo_metadata), response(OWNER, 404)
    ])
    assert_includes output, "owner github.com/example"
    assert_includes output, OWNER
    assert_equal "owner", failure["kind"]
    assert_equal OWNER, failure["endpoint"]
    assert_equal "github.com/example", CSV.read(@csv_path, headers: true).first["identifier"]
    assert_nil @db.get_first_value("SELECT owners_synced_at FROM owners")
    run_script("owners.rb", ["--failures", @csv_path], [
      response(LOOKUP, 200, repo_metadata), response(OWNER, 200, { "kind" => "user", "login" => "example" })
    ])
    assert_equal "user", @db.get_first_value("SELECT kind FROM owners")
    assert_empty CSV.read(@csv_path, headers: true)
  end

  def test_owner_repository_prerequisite_failure_keeps_its_endpoint
    run_script("owners.rb", [], [response(LOOKUP, 404)])
    assert_equal "owner", failure["kind"]
    assert_equal "github.com/example", failure["identifier"]
    assert_equal LOOKUP, failure["endpoint"]
    assert_equal 404, failure["http_status"]
  end

  def test_package_failures_are_distinct_and_clear_after_a_successful_import
    run_script("mydataset.rb", ["--refresh", "--failures", @csv_path, @input], [response(PACKAGE, 404)], success: false)
    assert_equal "package", failure["kind"]
    assert_equal "pkg:gem/example", failure["identifier"]
    assert_equal PACKAGE, failure["endpoint"]
    assert_equal 404, failure["http_status"]
    assert_equal "package", CSV.read(@csv_path, headers: true).first["kind"]
    run_script("mydataset.rb", ["--failures", @csv_path, @input], [response(PACKAGE, 200, @package)])
    assert_empty @db.execute("SELECT * FROM lookup_failures")
    assert_empty CSV.read(@csv_path, headers: true)
  end

  def prepare_report
    %w[situation eol_direct dead_transitive_count remediation alternative_purl remediation_notes
       remediation_source llm_confidence top1_dependent].each do |column|
      @db.execute("ALTER TABLE packages ADD COLUMN #{column}")
    end
    %w[code_loc complexity has_native].each { |column| @db.execute("ALTER TABLE repos ADD COLUMN #{column}") }
    url = "https://advisories.ecosyste.ms/api/v1/advisories?ecosystem=rubygems&package_name=example&per_page=100"
    run_script("advisories.rb", [], [response(url, 200, [])])
  end
end
