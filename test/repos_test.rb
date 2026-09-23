require_relative "test_helper"
require "sqlite3"
require "json"
require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "uri"
require "database"

class ReposTest < Minitest::Test
  OLD_URL = "https://github.com/trevorrowe/jmespath.rb"
  NEW_URL = "https://github.com/jmespath/jmespath.rb"
  API = "https://repos.ecosyste.ms"

  def setup
    @directory = Dir.mktmpdir("repos-test")
    FileUtils.cp(%w[repos.rb http.rb database.rb].map { |name| File.expand_path("../#{name}", __dir__) }, @directory)
    @cache = File.join(@directory, "cache", "repos")
    FileUtils.mkdir_p(@cache)
    @db = SQLite3::Database.new(File.join(@directory, "repos.db"))
    @db.results_as_hash = true
    Bernies.create_core_tables(@db)
    @db.execute("INSERT INTO repos (repository_url, host, owner) VALUES (?, ?, ?)",
      [OLD_URL, "github.com", "trevorrowe"])
    File.write(File.join(@directory, "adapter.rb"), <<~RUBY)
      require "faraday"
      require "json"
      class ScriptAdapter < Faraday::Adapter::Test
        STUBS = Faraday::Adapter::Test::Stubs.new do |stub|
          JSON.parse(File.read(ENV.fetch("HTTP_STUBS"))).each do |method, url, status, headers, body|
            stub.public_send(method, url) { [status, headers, body] }
          end
        end
        def initialize(app, *)
          super(app, STUBS)
        end
      end
      Faraday.default_adapter = ScriptAdapter
      at_exit { ScriptAdapter::STUBS.verify_stubbed_calls }
    RUBY
  end

  def teardown
    @db.close
    FileUtils.remove_entry(@directory)
  end

  def metadata
    { "stargazers_count" => 123, "archived" => false,
      "pushed_at" => "2026-09-01T00:00:00Z", "last_synced_at" => "2026-09-02T00:00:00Z" }
  end

  def lookup_url(url)
    "#{API}/api/v1/repositories/lookup?#{URI.encode_www_form(url: url)}"
  end

  def run_repos(stubs)
    File.write(File.join(@directory, "stubs.json"), JSON.generate(stubs))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => File.join(@directory, "repos.db"), "HTTP_STUBS" => File.join(@directory, "stubs.json") },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "adapter.rb"), File.join(@directory, "repos.rb"), "1"
    )
    assert status.success?, output
    output
  end

  def assert_refreshed(output)
    assert_includes output, "refreshed 1, no data for 0"
    row = @db.get_first_row("SELECT * FROM repos WHERE repository_url=?", OLD_URL)
    assert_equal 123, row["stars"]
    assert_equal 0, row["archived"]
    assert_equal metadata["pushed_at"], row["pushed_at"]
    assert_equal metadata["last_synced_at"], row["repos_synced_at"]
  end

  def test_refreshes_a_redirected_repository
    assert_refreshed run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, '{"error":"Repository not found"}'],
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(metadata)]
    ])

    @db.execute("UPDATE repos SET repos_synced_at=NULL")
    assert_refreshed run_repos([])
  end

  def test_recovers_an_existing_cached_miss
    key = Digest::SHA256.hexdigest(["#{API}/", "/api/v1/repositories/lookup", { url: OLD_URL }.sort].join("|"))[0, 32]
    File.write(File.join(@cache, "#{key}.json"), "null")
    assert_refreshed run_repos([
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(metadata)]
    ])
  end

  def test_does_not_probe_github_when_lookup_succeeds
    assert_refreshed run_repos([
      ["get", lookup_url(OLD_URL), 200, {}, JSON.generate(metadata)]
    ])
  end

  def test_missing_or_unmoved_repositories_remain_misses
    [200, 404].each do |status|
      output = run_repos([
        *([["get", lookup_url(OLD_URL), 404, {}, "null"]] if status == 200),
        ["head", OLD_URL, status, {}, ""]
      ])
      assert_includes output, "refreshed 0, no data for 1"
      assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")
    end
  end

  def test_follows_multiple_redirects
    middle = "https://github.com/another-owner/jmespath.rb"
    assert_refreshed run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, "null"],
      ["head", OLD_URL, 301, { "location" => middle }, ""],
      ["head", middle, 302, { "location" => "/jmespath/jmespath.rb" }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(metadata)]
    ])
  end

  def test_redirect_loop_remains_a_miss
    output = run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, "null"],
      ["head", OLD_URL, 301, { "location" => OLD_URL }, ""]
    ])
    assert_includes output, "refreshed 0, no data for 1"
    assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")
  end

  def test_does_not_probe_other_hosts
    url = "https://gitlab.com/example/repo"
    @db.execute("UPDATE repos SET repository_url=?, host='gitlab.com'", url)
    output = run_repos([["get", lookup_url(url), 404, {}, "null"]])
    assert_includes output, "refreshed 0, no data for 1"
  end

  def test_retries_a_failed_redirect_resolution_on_the_next_run
    output = run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, "null"],
      ["head", OLD_URL, 429, {}, ""]
    ])
    assert_includes output, "refreshed 0, no data for 1"
    assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")

    assert_refreshed run_repos([
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 200, {}, JSON.generate(metadata)]
    ])
  end

  def test_redirect_destination_without_metadata_remains_a_miss
    output = run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, "null"],
      ["head", OLD_URL, 301, { "location" => NEW_URL }, ""],
      ["head", NEW_URL, 200, {}, ""],
      ["get", lookup_url(NEW_URL), 404, {}, "null"]
    ])
    assert_includes output, "refreshed 0, no data for 1"
    assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")
  end

  def test_ignores_redirects_to_non_repository_pages
    login = "https://github.com/login"
    output = run_repos([
      ["get", lookup_url(OLD_URL), 404, {}, "null"],
      ["head", OLD_URL, 302, { "location" => login }, ""],
      ["head", login, 200, {}, ""]
    ])
    assert_includes output, "refreshed 0, no data for 1"
    assert_nil @db.get_first_value("SELECT repos_synced_at FROM repos")
  end
end
