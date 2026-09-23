require_relative "test_helper"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"

class PackageImportTest < Minitest::Test
  API = "https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages"

  def setup
    @directory = Dir.mktmpdir("package-import-test")
    @db_path = File.join(@directory, "custom.db")
    @input = File.join(@directory, "mydata.txt")
    FileUtils.cp(%w[mydataset.rb fetch.rb http.rb database.rb package_writer.rb].map { |name|
      File.expand_path("../#{name}", __dir__)
    }, @directory)
    File.write(File.join(@directory, "adapter.rb"), <<~RUBY)
      require "faraday"
      require "json"
      class ImportAdapter < Faraday::Adapter::Test
        STUBS = Faraday::Adapter::Test::Stubs.new do |stub|
          JSON.parse(File.read(ENV.fetch("HTTP_STUBS"))).each do |url, status, headers, body|
            stub.get(url) { [status, headers, body] }
          end
        end
        def initialize(app, *)
          super(app, STUBS)
        end
      end
      Faraday.default_adapter = ImportAdapter
      at_exit { ImportAdapter::STUBS.verify_stubbed_calls }
    RUBY
  end

  def teardown
    @db&.close
    FileUtils.remove_entry(@directory)
  end

  def db
    @db ||= SQLite3::Database.new(@db_path).tap { |database| database.results_as_hash = true }
  end

  def package(name = "spina", repository_url: "http://www.github.com/SpinaCMS/Spina.git/")
    {
      "purl" => "pkg:gem/#{name}", "name" => name, "ecosystem" => "rubygems",
      "repository_url" => repository_url,
      "dependent_repos_count" => 123, "downloads" => 456,
      "maintainers" => [{ "uuid" => "maintainer-1" }, { "login" => "maintainer-2" }],
      "repo_metadata" => {
        "stargazers_count" => 200, "archived" => false, "fork" => false,
        "has_issues" => true, "pull_requests_enabled" => true,
        "language" => "Ruby", "default_branch" => "main", "pushed_at" => "2026-09-01T00:00:00Z"
      }
    }
  end

  def response(name, data = package(name))
    ["#{API}/#{name}", 200, {}, JSON.generate(data)]
  end

  def run_script(script, args, stubs = [], success: true)
    File.write(File.join(@directory, "stubs.json"), JSON.generate(stubs))
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @db_path, "HTTP_STUBS" => File.join(@directory, "stubs.json") },
      RbConfig.ruby, "-r", "bundler/setup", "-r", File.join(@directory, "adapter.rb"),
      File.join(@directory, script), *args
    )
    assert_equal success, status.success?, output
    output
  end

  def test_imports_csv_with_optional_quoted_comments_and_blank_lines
    File.write(@input, "pkg:gem, spina\n\npkg:gem, katello, \"comment, with comma\"\n")
    output = run_script("mydataset.rb", [@input], [response("spina"), response("katello")])
    assert_includes output, "imported 2, unavailable 0"
    assert_equal 2, db.get_first_value("SELECT COUNT(*) FROM packages")
    assert_equal 1, db.get_first_value("SELECT COUNT(*) FROM repos")
    assert_package_stored
    refute File.exist?(File.join(@directory, "bernies.db"))
  end

  def assert_package_stored
    stored = db.get_first_row("SELECT * FROM packages WHERE purl='pkg:gem/spina'")
    assert_equal "rubygems.org", stored["registry"]
    assert_equal "rubygems", stored["ecosystem"]
    assert_equal "https://github.com/spinacms/spina", stored["repository_url"]
    assert_equal 123, stored["dependent_repos"]
    assert_equal 456, stored["downloads"]
    assert_equal 2, stored["registry_maintainers_count"]
    assert_equal "maintainer-1,maintainer-2", stored["registry_maintainers"]
    refute_nil stored["fetched_at"]
    repo = db.get_first_row("SELECT * FROM repos WHERE repository_url=?", stored["repository_url"])
    assert_equal "github.com", repo["host"]
    assert_equal "spinacms", repo["owner"]
    assert_equal 200, repo["stars"]
    assert_equal 0, repo["archived"]
    assert_equal 1, repo["has_issues"]
    assert_nil repo["repos_synced_at"]
  end

  def test_deduplicates_rows_and_reuses_cache_without_removing_other_packages
    File.write(@input, "pkg:gem, spina\npkg:gem, spina, repeated\npkg:gem, katello\n")
    run_script("mydataset.rb", [@input], [response("spina"), response("katello")])
    db.execute("UPDATE repos SET bucket='dormant', last_commit_at='2020-01-01T00:00:00Z'")

    File.write(@input, "pkg:gem, spina\n")
    output = run_script("mydataset.rb", [@input])
    assert_includes output, "imported 1, unavailable 0"
    assert_equal 2, db.get_first_value("SELECT COUNT(*) FROM packages")
    assert_equal 1, db.get_first_value("SELECT COUNT(*) FROM repos")
    assert_equal "dormant", db.get_first_value("SELECT bucket FROM repos")
    assert_equal "2020-01-01T00:00:00Z", db.get_first_value("SELECT last_commit_at FROM repos")
  end

  def test_imports_a_package_without_a_repository
    File.write(@input, "pkg:gem, spina\n")
    run_script("mydataset.rb", [@input], [response("spina", package(repository_url: nil))])
    assert_equal 1, db.get_first_value("SELECT COUNT(*) FROM packages")
    assert_equal 0, db.get_first_value("SELECT COUNT(*) FROM repos")
  end

  def test_reports_missing_packages_and_keeps_successful_imports
    File.write(@input, "pkg:gem, missing\npkg:gem, spina\n")
    output = run_script("mydataset.rb", [@input], [
      ["#{API}/missing", 404, {}, '{"error":"Package not found"}'], response("spina")
    ], success: false)
    assert_includes output, "missing: package not found or unavailable"
    assert_includes output, "imported 1, unavailable 1"
    assert_equal ["spina"], db.execute("SELECT name FROM packages").map { |row| row["name"] }
  end

  def test_rejects_invalid_rows_before_importing_any_packages
    ["pkg:gem. ckeditor", "pkg:npm, spina", "pkg:gem,", "pkg:gem, spina, comment, extra"].each do |invalid|
      File.write(@input, "pkg:gem, spina\n#{invalid}\n")
      output = run_script("mydataset.rb", [@input], success: false)
      assert_includes output, "row 2: expected pkg:gem,name[,comment]"
      refute File.exist?(@db_path)
    end
  end

  def test_reports_malformed_csv
    File.write(@input, "pkg:gem, spina\npkg:gem, katello, \"unclosed\n")
    output = run_script("mydataset.rb", [@input], success: false)
    assert_includes output, "Unclosed quoted field"
    refute File.exist?(@db_path)
  end

  def test_requires_a_readable_nonempty_file
    output = run_script("mydataset.rb", [], success: false)
    assert_includes output, "Usage: ruby mydataset.rb FILE"
    output = run_script("mydataset.rb", [@input], success: false)
    assert_includes output, "No such file"
    File.write(@input, "\n")
    output = run_script("mydataset.rb", [@input], success: false)
    assert_includes output, "No packages"
    refute File.exist?(@db_path)
  end

  def test_fetch_still_imports_paginated_critical_packages
    first = "#{API}?critical=true&per_page=100&page=1"
    second = "#{API}?critical=true&per_page=100&page=2"
    output = run_script("fetch.rb", ["rubygems.org"], [
      [first, 200, { "link" => "<#{second}>; rel=\"next\"" }, JSON.generate([package])],
      [second, 200, {}, JSON.generate([package("katello"), { "name" => "no-purl" }])]
    ])
    assert_includes output, "2 packages, 1 repos"
    assert_package_stored
    output = run_script("fetch.rb", ["rubygems.org"])
    assert_includes output, "2 packages, 1 repos"
  end
end
