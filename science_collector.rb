require "digest"
require "fileutils"
require "json"
require "sqlite3"
require "time"
require_relative "database"

module Bernies
  class ScienceClient
    def initialize(connection, cache_dir, delay: 0.1)
      @connection = connection
      @cache_dir = cache_dir
      @delay = delay
      FileUtils.mkdir_p(@cache_dir)
    end

    def ranking_page(page)
      fetch("/projects", { page: page }, "text/html", "html")
    end

    def project(id)
      JSON.parse(fetch("/api/v1/projects/#{id}", {}, "application/json", "json"))
    end

    def fetch(path, params, accept, extension)
      key = Digest::SHA256.hexdigest([path, params.sort].join("|"))[0, 32]
      cache_path = File.join(@cache_dir, "#{key}.#{extension}")
      return File.read(cache_path) if File.exist?(cache_path)

      response = @connection.get(path, params) do |request|
        request.headers["Accept"] = accept
      end
      raise "#{response.status} for #{path}" unless response.success?

      File.write(cache_path, response.body)
      sleep @delay
      response.body
    end
  end

  class ScienceCollector
    SCIENCE_COLUMNS = %w[
      science_id rank name description repository_url science_score project_score
      total_citations category sub_category language monthly_downloads packages_count
      owner_login owner_name owner_kind owner_company owner_website
      science_project_url science_html_url science_synced_at collected_at
    ].freeze

    PACKAGE_COLUMNS = %w[
      purl registry ecosystem name repository_url
      dependent_repos dependent_packages downloads downloads_period
      latest_release latest_release_at first_release_at versions_count
      status rankings_avg registry_maintainers_count registry_maintainers fetched_at
    ].freeze

    REPO_COLUMNS = %w[
      repository_url host owner stars forks open_issues archived fork repo_status
      has_issues prs_enabled language license default_branch repo_created_at pushed_at
    ].freeze

    def initialize(db_path:, client:, clock: -> { Time.now.utc })
      @db_path = db_path
      @client = client
      @clock = clock
    end

    def collect(target)
      raise ArgumentError, "target must be positive" unless target.positive?

      db = SQLite3::Database.new(@db_path)
      db.busy_timeout = 5000
      Bernies.create_core_tables(db)
      create_science_table(db)

      collected_at = @clock.call.iso8601(6)
      rank = 0
      page = 0

      science_insert = prepare_science_insert(db)
      package_insert = prepare_package_insert(db)
      repo_insert = prepare_repo_insert(db)

      db.transaction
      while rank < target
        page += 1
        entries = ranking_entries(@client.ranking_page(page))
        raise "science ranking page #{page} contained no projects" if entries.empty?

        entries.each do |entry|
          break if rank >= target

          project = @client.project(entry.fetch("id"))
          repository_url = repository_url(project)
          next unless repository_url

          rank += 1
          write_science_project(science_insert, project, entry, repository_url, rank, collected_at)
          write_repository(repo_insert, project, repository_url)
          write_packages(package_insert, project, repository_url, collected_at)
          print "\rpage #{page}  (#{rank}/#{target} projects)"
        end
      end
      db.execute("DELETE FROM science_projects WHERE collected_at <> ?", collected_at)
      db.commit
      puts

      science_insert.close
      package_insert.close
      repo_insert.close
      db.close
      rank
    rescue
      db&.rollback rescue nil
      raise
    end

    def ranking_entries(html)
      html.scan(
        /<div\b[^>]*\bid="project_(\d+)"[^>]*>(.*?)(?=<div\b[^>]*\bid="project_\d+"|\z)/m
      ).map do |id, card|
        science_score = card[/Science\s+([0-9]+(?:\.[0-9]+)?)%/, 1]
        {
          "id" => id.to_i,
          "science_score" => science_score&.to_f
        }
      end
    end

    def create_science_table(db)
      db.execute_batch <<~SQL
        CREATE TABLE IF NOT EXISTS science_projects (
          science_id          INTEGER PRIMARY KEY,
          rank                INTEGER NOT NULL,
          name                TEXT,
          description         TEXT,
          repository_url      TEXT NOT NULL,
          science_score       REAL,
          project_score       REAL,
          total_citations     INTEGER,
          category            TEXT,
          sub_category        TEXT,
          language            TEXT,
          monthly_downloads   INTEGER,
          packages_count      INTEGER,
          owner_login         TEXT,
          owner_name          TEXT,
          owner_kind          TEXT,
          owner_company       TEXT,
          owner_website       TEXT,
          science_project_url TEXT,
          science_html_url    TEXT,
          science_synced_at   TEXT,
          collected_at        TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_science_projects_rank
          ON science_projects(rank);
        CREATE INDEX IF NOT EXISTS idx_science_projects_repo
          ON science_projects(repository_url);
      SQL
    end

    def prepare_science_insert(db)
      db.prepare <<~SQL
        INSERT INTO science_projects (#{SCIENCE_COLUMNS.join(",")})
        VALUES (#{(["?"] * SCIENCE_COLUMNS.size).join(",")})
        ON CONFLICT(science_id) DO UPDATE SET
          #{(SCIENCE_COLUMNS - ["science_id"]).map { |column| "#{column}=excluded.#{column}" }.join(",")}
      SQL
    end

    def prepare_package_insert(db)
      db.prepare <<~SQL
        INSERT INTO packages (#{PACKAGE_COLUMNS.join(",")})
        VALUES (#{(["?"] * PACKAGE_COLUMNS.size).join(",")})
        ON CONFLICT(purl) DO UPDATE SET
          #{(PACKAGE_COLUMNS - %w[purl registry ecosystem name]).map { |column| "#{column}=excluded.#{column}" }.join(",")}
      SQL
    end

    def prepare_repo_insert(db)
      db.prepare <<~SQL
        INSERT INTO repos (#{REPO_COLUMNS.join(",")})
        VALUES (#{(["?"] * REPO_COLUMNS.size).join(",")})
        ON CONFLICT(repository_url) DO UPDATE SET
          #{(REPO_COLUMNS - %w[repository_url host owner]).map { |column|
            "#{column}=CASE WHEN repos.repos_synced_at IS NULL " \
              "THEN COALESCE(excluded.#{column},repos.#{column}) ELSE repos.#{column} END"
          }.join(",")}
      SQL
    end

    def write_science_project(statement, project, entry, repo_url, rank, collected_at)
      owner = project["owner"] || {}
      packages = project["packages"] || []
      statement.execute(
        project.fetch("id"),
        rank,
        project["name"],
        project["description"],
        repo_url,
        entry["science_score"],
        project["score"],
        project["total_citations"],
        project["category"],
        project["sub_category"],
        project["language"] || project.dig("repository", "language"),
        project["monthly_downloads"],
        packages.size,
        owner["login"],
        owner["name"],
        owner["kind"],
        owner["company"],
        owner["website"],
        project["project_url"],
        project["html_url"],
        project["last_synced_at"],
        collected_at
      )
    end

    def write_repository(statement, project, repo_url)
      metadata = project["repository"] || {}
      host, owner = owner_from(repo_url)
      boolean = ->(value) { value.nil? ? nil : (value ? 1 : 0) }
      statement.execute(
        repo_url,
        host,
        owner,
        metadata["stargazers_count"],
        metadata["forks_count"],
        metadata["open_issues_count"],
        boolean.call(metadata["archived"]),
        boolean.call(metadata["fork"]),
        metadata["status"],
        boolean.call(metadata["has_issues"]),
        boolean.call(metadata["pull_requests_enabled"]),
        metadata["language"],
        metadata["license"],
        metadata["default_branch"],
        metadata["created_at"],
        metadata["pushed_at"]
      )
    end

    def write_packages(statement, project, repo_url, collected_at)
      (project["packages"] || []).each do |package|
        purl = package["purl"]
        next unless purl

        registry = package["registry"].is_a?(Hash) ? package.dig("registry", "name") : package["registry"]
        maintainers = (package["maintainers"] || []).filter_map { |maintainer| maintainer["uuid"] || maintainer["login"] }
        statement.execute(
          purl,
          registry || "unknown",
          package["ecosystem"] || registry || "unknown",
          package["name"] || purl,
          repo_url,
          package["dependent_repos_count"],
          package["dependent_packages_count"],
          package["downloads"],
          package["downloads_period"],
          package["latest_release_number"],
          package["latest_release_published_at"],
          package["first_release_published_at"],
          package["versions_count"],
          package["status"],
          package.dig("rankings", "average"),
          maintainers.size,
          maintainers.join(","),
          collected_at
        )
      end
    end

    def repository_url(project)
      normalize_repository_url(project.dig("repository", "html_url") || project["url"])
    end

    def normalize_repository_url(url)
      return nil if url.nil? || url.strip.empty?

      normalized = url.strip.sub(%r{\Ahttp://}, "https://")
      return nil unless normalized.start_with?("https://")

      normalized
        .sub(%r{\Ahttps://www\.}, "https://")
        .chomp("/")
        .chomp(".git")
        .downcase
    end

    def owner_from(url)
      parts = url.sub(%r{\Ahttps?://}, "").split("/")
      [parts[0], parts[1]]
    end
  end
end
