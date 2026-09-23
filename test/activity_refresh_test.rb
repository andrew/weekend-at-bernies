require_relative "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "uri"
require "database"

class ActivityRefreshTest < Minitest::Test
  REPOSITORY = "https://github.com/example/project"

  def setup
    @directory = Dir.mktmpdir("activity-refresh-test")
    FileUtils.cp(%w[commits.rb issues.rb classify.rb http.rb database.rb].map { |name|
      File.expand_path("../#{name}", __dir__)
    }, @directory)
    FileUtils.cp(File.expand_path("http_adapter.rb", __dir__), @directory)
    @db_path = File.join(@directory, "custom.db")
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    Bernies.create_core_tables(@db)
    @db.execute("INSERT INTO repos (repository_url, host, past_year_issues, issues_synced_at) VALUES (?, ?, ?, ?)",
      [REPOSITORY, "github.com", 1, "2020-01-01T00:00:00Z"])
  end

  def teardown
    @db.close
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

  def response(service, metadata, status = 200)
    url = "https://#{service}.ecosyste.ms/api/v1/repositories/lookup?#{URI.encode_www_form(url: REPOSITORY)}"
    ["get", url, status, {}, JSON.generate(metadata)]
  end

  def test_refresh_updates_synced_activity_and_changes_classification
    {
      "commits" => ["past_year_commits", { "past_year_total_commits" => 15 }],
      "issues" => ["active_maintainers_count", { "active_maintainers" => [{ "login" => "maintainer" }] }]
    }.each do |service, (column, activity)|
      @db.execute("UPDATE repos SET commits_synced_at=NULL, issues_synced_at=NULL, past_year_commits=0, active_maintainers_count=0")
      baseline = { "last_synced_at" => "2026-08-01T00:00:00Z", "past_year_issues_count" => 1,
                   "past_year_total_commits" => 0 }
      run_script("#{service}.rb", [], [response(service, baseline)])
      @db.execute("UPDATE repos SET issues_synced_at=COALESCE(issues_synced_at, ?)", [baseline["last_synced_at"]])
      run_script("classify.rb")
      assert_equal "dead", @db.get_first_value("SELECT bucket FROM repos")
      assert_includes run_script("#{service}.rb"), "0 repos to enrich"

      @db.execute("INSERT INTO repos (repository_url, host) VALUES (?, 'github.com')", ["https://github.com/z-example/untouched"])
      fresh = baseline.merge(activity).merge("last_synced_at" => "2026-09-23T00:00:00Z")
      run_script("#{service}.rb", ["--refresh", "1"], [response(service, fresh)])
      assert_operator @db.get_first_value("SELECT #{column} FROM repos WHERE repository_url=?", [REPOSITORY]), :>, 0
      assert_equal fresh["last_synced_at"], @db.get_first_value("SELECT #{service}_synced_at FROM repos WHERE repository_url=?", [REPOSITORY])
      assert_nil @db.get_first_value("SELECT #{service}_synced_at FROM repos WHERE repository_url=?", ["https://github.com/z-example/untouched"])
      @db.execute("DELETE FROM repos WHERE repository_url <> ?", [REPOSITORY])
      run_script("classify.rb")
      assert_equal(service == "commits" ? "active" : "dormant", @db.get_first_value("SELECT bucket FROM repos"))

      @db.execute("UPDATE repos SET #{service}_synced_at=NULL, #{column}=0")
      run_script("#{service}.rb")
      assert_operator @db.get_first_value("SELECT #{column} FROM repos"), :>, 0
    end
  end

  def test_failed_refresh_preserves_existing_activity
    %w[commits issues].each do |service|
      @db.execute("UPDATE repos SET #{service}_synced_at=?, past_year_commits=15, active_maintainers_count=1",
        ["2026-08-01T00:00:00Z"])
      output = run_script("#{service}.rb", ["--refresh"], [response(service, nil, 404)])
      assert_includes output, "enriched 0, no data for 1"
      assert_equal "2026-08-01T00:00:00Z", @db.get_first_value("SELECT #{service}_synced_at FROM repos")
      assert_equal 15, @db.get_first_value("SELECT past_year_commits FROM repos")
      assert_equal 1, @db.get_first_value("SELECT active_maintainers_count FROM repos")
    end
  end
end
