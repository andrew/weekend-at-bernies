require_relative "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"
require "digest"
require "database"

class IssuesRedirectTest < Minitest::Test
  OLD_URL = "https://github.com/dcodeIO/protobuf.js"
  NEW_URL = "https://github.com/protobufjs/protobuf.js"
  API = "https://issues.ecosyste.ms"

  def setup
    @directory = Dir.mktmpdir("issues-redirect-test")
    FileUtils.cp(%w[issues.rb http.rb database.rb].map { |name| File.expand_path("../#{name}", __dir__) }, @directory)
    FileUtils.cp(File.expand_path("http_adapter.rb", __dir__), @directory)
    @db_path = File.join(@directory, "issues.db")
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    Bernies.create_core_tables(@db)
    @db.execute("INSERT INTO repos (repository_url, host) VALUES (?, ?)", [OLD_URL, "github.com"])
  end

  def teardown
    @db.close
    FileUtils.remove_entry(@directory)
  end

  def lookup_url(url)
    "#{API}/api/v1/repositories/lookup?#{URI.encode_www_form(url: url)}"
  end

  def run_issues(stubs)
    stub_path = File.join(@directory, "stubs.json")
    File.write(stub_path, JSON.generate(stubs))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @db_path, "HTTP_STUBS" => stub_path },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "http_adapter.rb"),
      File.join(@directory, "issues.rb")
    )
    assert status.success?, output
    output
  end

  def not_found_record
    { "full_name" => "dcodeIO/protobuf.js", "status" => "not_found", "last_synced_at" => nil, "issues_count" => nil }
  end

  def test_looks_up_the_new_name_when_the_old_one_is_not_found
    synced = { "full_name" => "protobufjs/protobuf.js", "status" => nil, "last_synced_at" => "2026-11-02T13:11:36Z",
               "issues_count" => 269, "pull_requests_count" => 40,
               "active_maintainers" => [{ "login" => "maintainer" }] }
    output = run_issues([
      ["get", lookup_url(OLD_URL), 200, {}, JSON.generate(not_found_record)],
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(synced)]
    ])

    assert_includes output, "enriched 1, no data for 0"
    row = @db.get_first_row("SELECT * FROM repos WHERE repository_url=?", OLD_URL)
    assert_equal 269, row["issues_count"]
    assert_equal 1, row["active_maintainers_count"]
    assert_equal "2026-11-02T13:11:36Z", row["issues_synced_at"]
  end

  def test_refetches_a_cached_pending_response
    key = Digest::SHA256.hexdigest(["#{API}/", "/api/v1/repositories/lookup", { url: OLD_URL }.sort].join("|"))[0, 32]
    FileUtils.mkdir_p(File.join(@directory, "cache", "issues"))
    File.write(File.join(@directory, "cache", "issues", "#{key}.json"), JSON.generate("status" => "pending"))
    synced = { "full_name" => "protobufjs/protobuf.js", "last_synced_at" => "2026-11-02T13:11:36Z", "issues_count" => 269 }
    run_issues([
      ["get", lookup_url(OLD_URL), 200, {}, JSON.generate(not_found_record)],
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(synced)]
    ])

    assert_equal 269, @db.get_first_value("SELECT issues_count FROM repos WHERE repository_url=?", OLD_URL)
  end

  def test_leaves_a_deleted_repository_without_issue_data
    run_issues([
      ["get", lookup_url(OLD_URL), 200, {}, JSON.generate(not_found_record)],
      ["head", OLD_URL, 404, {}, ""]
    ])

    row = @db.get_first_row("SELECT * FROM repos WHERE repository_url=?", OLD_URL)
    assert_nil row["issues_count"]
    assert_nil row["issues_synced_at"]
  end
end
