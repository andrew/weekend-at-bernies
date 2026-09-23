require_relative "test_helper"
require "csv"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "sqlite3"
require "database"

class AdvisoriesTest < Minitest::Test
  REPOSITORY = "https://github.com/devise-two-factor/devise-two-factor"
  IDENTIFIER = "GHSA-qjxf-mc72-wjr2"

  def setup
    @directory = Dir.mktmpdir("advisories-test")
    FileUtils.cp(%w[advisories.rb report.rb http.rb database.rb].map { |name|
      File.expand_path("../#{name}", __dir__)
    }, @directory)
    @db_path = File.join(@directory, "bernies.db")
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    Bernies.create_core_tables(@db)
    @db.execute("INSERT INTO repos (repository_url, bucket) VALUES (?, 'active')", [REPOSITORY])
    @db.execute(<<~SQL, [REPOSITORY])
      INSERT INTO packages (purl, registry, ecosystem, name, repository_url, fetched_at)
      VALUES ('pkg:gem/devise-two-factor', 'rubygems.org', 'rubygems', 'devise-two-factor', ?, '2026-09-23T00:00:00Z')
    SQL
    %w[situation eol_direct dead_transitive_count remediation alternative_purl
       remediation_notes remediation_source llm_confidence top1_dependent].each do |column|
      @db.execute("ALTER TABLE packages ADD COLUMN #{column}")
    end
    %w[code_loc complexity has_native].each do |column|
      @db.execute("ALTER TABLE repos ADD COLUMN #{column}")
    end
    cache = File.join(@directory, "cache", "advisories")
    FileUtils.mkdir_p(cache)
    params = { ecosystem: "rubygems", package_name: "devise-two-factor", per_page: 100 }
    key = Digest::SHA256.hexdigest(["https://advisories.ecosyste.ms/", "/api/v1/advisories", params.sort].join("|"))[0, 32]
    @cache_path = File.join(cache, "#{key}.json")
  end

  def teardown
    @db.close
    FileUtils.remove_entry(@directory)
  end

  def advisory
    {
      "identifiers" => [IDENTIFIER, "CVE-2024-8796"],
      "severity" => "MODERATE", "cvss_score" => 6.0,
      "published_at" => "2024-09-17T21:31:50.000Z", "withdrawn_at" => nil,
      "packages" => [{
        "ecosystem" => "rubygems", "package_name" => "devise-two-factor",
        "versions" => [
          { "vulnerable_version_range" => "= 1.0.0", "first_patched_version" => nil },
          { "vulnerable_version_range" => ">= 4.0.0, < 6.0.0", "first_patched_version" => "6.0.0" }
        ]
      }]
    }
  end

  def run_script(name)
    output, status = Open3.capture2e(
      { "BERNIES_DB" => @db_path }, RbConfig.ruby, "-r", "bundler/setup", File.join(@directory, name)
    )
    assert status.success?, output
    output
  end

  def import(data)
    File.write(@cache_path, JSON.generate([data]))
    run_script("advisories.rb")
  end

  def assert_patch_status(patched)
    assert_equal patched, @db.get_first_value("SELECT patched FROM advisories")
    assert_equal 1, @db.get_first_value("SELECT advisories_count FROM repos")
    assert_equal 1 - patched, @db.get_first_value("SELECT unpatched_advisories_count FROM repos")
    run_script("report.rb")
    rows = CSV.read(File.join(@directory, "out", "unpatched.csv"), headers: true)
    assert_equal(patched == 1 ? [] : [IDENTIFIER], rows.map { |row| row["identifier"] })
  end

  def test_patch_for_one_range_is_enough_even_when_another_range_has_no_patch_metadata
    output = import(advisory)
    assert_includes output, "1 advisory rows, 0 unpatched"
    assert_patch_status(1)
    assert_equal "6.0.0", @db.get_first_value("SELECT first_patched_version FROM advisories")
    assert_equal "= 1.0.0; >= 4.0.0, < 6.0.0", @db.get_first_value("SELECT vulnerable_range FROM advisories")
  end

  def test_rerun_corrects_previously_unpatched_rows_using_cached_metadata
    import(advisory)
    @db.execute("UPDATE advisories SET patched=0")
    @db.execute("UPDATE repos SET unpatched_advisories_count=1")
    run_script("advisories.rb")
    assert_equal 1, @db.get_first_value("SELECT COUNT(*) FROM advisories")
    assert_patch_status(1)
  end

  def test_all_ranges_with_patches_remain_patched
    data = advisory
    data["packages"].first["versions"].first["first_patched_version"] = "6.0.0"
    import(data)
    assert_patch_status(1)
  end

  def test_missing_and_blank_patch_versions_remain_unpatched
    [nil, "", " \t "].each do |missing|
      data = advisory
      data["packages"].first["versions"].last["first_patched_version"] = missing
      import(data)
      assert_patch_status(0)
    end
  end

  def test_empty_version_metadata_remains_unpatched
    data = advisory
    data["packages"].first["versions"] = []
    import(data)
    assert_patch_status(0)
  end

  def test_patch_for_another_package_does_not_count
    data = advisory
    data["packages"].unshift({
      "ecosystem" => "rubygems", "package_name" => "another-package",
      "versions" => data["packages"].first["versions"]
    })
    data["packages"].last["versions"] = [{ "vulnerable_version_range" => "= 1.0.0" }]
    import(data)
    assert_patch_status(0)
  end
end
