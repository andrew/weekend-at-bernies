require "time"

module Bernies
  class PackageWriter
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

    def initialize(db)
      @db = db
      @packages = db.prepare <<~SQL
        INSERT INTO packages (#{PACKAGE_COLUMNS.join(",")}) VALUES (#{(["?"] * PACKAGE_COLUMNS.size).join(",")})
        ON CONFLICT(purl) DO UPDATE SET
          #{(PACKAGE_COLUMNS - %w[purl registry ecosystem name]).map { |c| "#{c}=excluded.#{c}" }.join(",")}
      SQL
      @repos = db.prepare <<~SQL
        INSERT INTO repos (#{REPO_COLUMNS.join(",")}) VALUES (#{(["?"] * REPO_COLUMNS.size).join(",")})
        ON CONFLICT(repository_url) DO UPDATE SET
          #{(REPO_COLUMNS - %w[repository_url host owner]).map { |c| "#{c}=COALESCE(excluded.#{c}, #{c})" }.join(",")}
        WHERE repos.repos_synced_at IS NULL
      SQL
      @now = Time.now.utc.iso8601
    end

    def write(package, registry)
      purl = package["purl"]
      return false unless purl

      repo = normalize_repository_url(package["repository_url"])
      maintainers = (package["maintainers"] || []).filter_map { |m| m["uuid"] || m["login"] }
      @packages.execute(
        purl, registry, package["ecosystem"], package["name"], repo,
        package["dependent_repos_count"], package["dependent_packages_count"],
        package["downloads"], package["downloads_period"],
        package["latest_release_number"], package["latest_release_published_at"],
        package["first_release_published_at"], package["versions_count"],
        package["status"], (package["rankings"] || {})["average"],
        maintainers.size, maintainers.join(","), @now
      )
      if repo
        host, owner = repo.delete_prefix("https://").split("/")
        metadata = package["repo_metadata"] || {}
        boolean = ->(value) { value.nil? ? nil : (value ? 1 : 0) }
        @repos.execute(
          repo, host, owner,
          metadata["stargazers_count"], metadata["forks_count"], metadata["open_issues_count"],
          boolean.call(metadata["archived"]), boolean.call(metadata["fork"]), metadata["status"],
          boolean.call(metadata["has_issues"]), boolean.call(metadata["pull_requests_enabled"]),
          metadata["language"], metadata["license"], metadata["default_branch"],
          metadata["created_at"], metadata["pushed_at"]
        )
      end
      true
    end

    def normalize_repository_url(url)
      return nil if url.nil? || url.strip.empty?

      url = url.strip.sub(%r{^http://}, "https://")
      return nil unless url.start_with?("https://")

      url.sub(%r{://www\.}, "://").chomp("/").chomp(".git").downcase
    end

    def close
      @packages.close
      @repos.close
    end

    def prune_repositories
      unused = "NOT EXISTS (SELECT 1 FROM packages p WHERE p.repository_url=repos.repository_url)"
      if @db.get_first_value("SELECT 1 FROM sqlite_master WHERE type='table' AND name='science_projects'")
        unused += " AND NOT EXISTS (SELECT 1 FROM science_projects s WHERE s.repository_url=repos.repository_url)"
      end

      @db.transaction do
        if @db.get_first_value("SELECT 1 FROM sqlite_master WHERE type='table' AND name='advisories'")
          @db.execute <<~SQL
            UPDATE advisories SET repository_url=(SELECT p.repository_url FROM packages p WHERE p.purl=advisories.purl)
            WHERE EXISTS (SELECT 1 FROM packages p WHERE p.purl=advisories.purl AND p.repository_url IS NOT advisories.repository_url)
          SQL
        end
        @db.execute("DELETE FROM repos WHERE #{unused}")
        if @db.get_first_value("SELECT 1 FROM sqlite_master WHERE type='table' AND name='lookup_failures'")
          @db.execute <<~SQL
            DELETE FROM lookup_failures
            WHERE repository_url IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM repos r WHERE r.repository_url=lookup_failures.repository_url)
              AND (kind='repository' OR (kind='owner' AND NOT EXISTS (
                SELECT 1 FROM repos r WHERE LOWER(r.host || '/' || r.owner)=LOWER(lookup_failures.identifier)
              )))
          SQL
          @db.execute <<~SQL
            UPDATE lookup_failures SET repository_url=(
              SELECT MIN(r.repository_url) FROM repos r WHERE LOWER(r.host || '/' || r.owner)=LOWER(lookup_failures.identifier)
            )
            WHERE kind='owner' AND repository_url IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM repos r WHERE r.repository_url=lookup_failures.repository_url)
          SQL
        end
      end
    end
  end
end
