require_relative "test_helper"
require "science_collector"

class ScienceCollectorTest < Minitest::Test
  class FakeClient
    def initialize(pages:, projects:)
      @pages = pages
      @projects = projects
    end

    def ranking_page(page)
      @pages.fetch(page)
    end

    def project(id)
      @projects.fetch(id)
    end
  end

  def ranking_html
    <<~HTML
      <div class="card listing" id="project_42">
        <h3>First project <span>• Rank 12.5 • Science 91%</span></h3>
      </div>
      <div class="card listing" id="project_84">
        <h3>Second project <span>• Rank 10.1 • Science 76.5%</span></h3>
      </div>
    HTML
  end

  def project(id:, name:, url:, package: nil)
    {
      "id" => id,
      "name" => name,
      "description" => "#{name} description",
      "url" => url,
      "last_synced_at" => "2026-07-29T12:00:00Z",
      "repository" => {
        "html_url" => url,
        "stargazers_count" => 100 + id,
        "forks_count" => 5,
        "open_issues_count" => 3,
        "archived" => false,
        "fork" => false,
        "status" => nil,
        "has_issues" => true,
        "pull_requests_enabled" => true,
        "language" => "Ruby",
        "license" => "mit",
        "default_branch" => "main",
        "created_at" => "2020-01-01T00:00:00Z",
        "pushed_at" => "2026-07-01T00:00:00Z"
      },
      "owner" => {
        "login" => "research-lab",
        "name" => "Research Lab",
        "kind" => "organization",
        "company" => "Example University",
        "website" => "https://example.edu"
      },
      "packages" => package ? [package] : [],
      "score" => 12.5,
      "total_citations" => 37,
      "category" => "Scientific Software",
      "sub_category" => "Peer-reviewed",
      "language" => "Ruby",
      "monthly_downloads" => 200,
      "project_url" => "https://science.ecosyste.ms/api/v1/projects/#{id}",
      "html_url" => "https://science.ecosyste.ms/projects/#{id}"
    }
  end

  def package
    {
      "purl" => "pkg:gem/science-tool",
      "registry" => { "name" => "rubygems.org" },
      "ecosystem" => "rubygems",
      "name" => "science-tool",
      "dependent_repos_count" => 12,
      "dependent_packages_count" => 7,
      "downloads" => 200,
      "downloads_period" => "last-month",
      "latest_release_number" => "2.0.0",
      "latest_release_published_at" => "2026-06-01T00:00:00Z",
      "first_release_published_at" => "2020-01-01T00:00:00Z",
      "versions_count" => 8,
      "status" => nil,
      "rankings" => { "average" => 8.2 },
      "maintainers" => [{ "uuid" => "maintainer-1" }]
    }
  end

  def test_extracts_ranked_project_ids_and_science_scores
    collector = Bernies::ScienceCollector.new(
      db_path: "/tmp/unused.db",
      client: FakeClient.new(pages: {}, projects: {})
    )

    assert_equal(
      [
        { "id" => 42, "science_score" => 91.0 },
        { "id" => 84, "science_score" => 76.5 }
      ],
      collector.ranking_entries(ranking_html)
    )
  end

  def test_collects_science_projects_repositories_and_packages
    Dir.mktmpdir("science-collector-test") do |directory|
      db_path = File.join(directory, "science.db")
      client = FakeClient.new(
        pages: { 1 => ranking_html },
        projects: {
          42 => project(
            id: 42,
            name: "First project",
            url: "http://www.github.com/Research-Lab/Science-Tool.git/",
            package: package
          ),
          84 => project(
            id: 84,
            name: "Second project",
            url: "https://github.com/Research-Lab/Second"
          )
        }
      )
      collector = Bernies::ScienceCollector.new(
        db_path: db_path,
        client: client,
        clock: -> { Time.utc(2026, 7, 30, 12) }
      )

      assert_equal 2, collector.collect(2)

      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true

      science = db.get_first_row("SELECT * FROM science_projects WHERE science_id=42")
      assert_equal 1, science["rank"]
      assert_equal 91.0, science["science_score"]
      assert_equal "research-lab", science["owner_login"]
      assert_equal "Example University", science["owner_company"]
      assert_equal "https://github.com/research-lab/science-tool", science["repository_url"]

      repository = db.get_first_row("SELECT * FROM repos WHERE repository_url=?", science["repository_url"])
      assert_equal "github.com", repository["host"]
      assert_equal "research-lab", repository["owner"]
      assert_equal 142, repository["stars"]
      assert_nil repository["repos_synced_at"]

      db.execute(
        "UPDATE repos SET stars=999, repos_synced_at='2026-07-30T13:00:00Z' WHERE repository_url=?",
        science["repository_url"]
      )
      collector.collect(2)
      refreshed_repository = db.get_first_row(
        "SELECT * FROM repos WHERE repository_url=?",
        science["repository_url"]
      )
      assert_equal 999, refreshed_repository["stars"]
      assert_equal "2026-07-30T13:00:00Z", refreshed_repository["repos_synced_at"]

      stored_package = db.get_first_row("SELECT * FROM packages WHERE purl='pkg:gem/science-tool'")
      assert_equal "rubygems", stored_package["ecosystem"]
      assert_equal 1, stored_package["registry_maintainers_count"]
      assert_equal science["repository_url"], stored_package["repository_url"]
    end
  end
end
