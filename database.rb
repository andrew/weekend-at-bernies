module Bernies
  def self.database_path(default_name = "bernies.db")
    File.expand_path(ENV.fetch("BERNIES_DB", default_name), __dir__)
  end

  def self.create_core_tables(db)
    db.execute_batch <<~SQL
      PRAGMA journal_mode=WAL;

      CREATE TABLE IF NOT EXISTS packages (
        purl                TEXT PRIMARY KEY,
        registry            TEXT NOT NULL,
        ecosystem           TEXT NOT NULL,
        name                TEXT NOT NULL,
        repository_url      TEXT,
        dependent_repos     INTEGER,
        dependent_packages  INTEGER,
        downloads           INTEGER,
        downloads_period    TEXT,
        latest_release      TEXT,
        latest_release_at   TEXT,
        first_release_at    TEXT,
        versions_count      INTEGER,
        status              TEXT,
        rankings_avg        REAL,
        registry_maintainers_count INTEGER,
        registry_maintainers TEXT,
        fetched_at          TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_packages_repo     ON packages(repository_url);
      CREATE INDEX IF NOT EXISTS idx_packages_registry ON packages(registry);

      CREATE TABLE IF NOT EXISTS repos (
        repository_url      TEXT PRIMARY KEY,
        host                TEXT,
        owner               TEXT,
        stars               INTEGER,
        forks               INTEGER,
        open_issues         INTEGER,
        archived            INTEGER,
        fork                INTEGER,
        repo_status         TEXT,
        has_issues          INTEGER,
        prs_enabled         INTEGER,
        language            TEXT,
        license             TEXT,
        default_branch      TEXT,
        repo_created_at     TEXT,
        pushed_at           TEXT,
        repos_synced_at     TEXT,

        last_commit_at      TEXT,
        last_commit_sha     TEXT,
        cloned_at           TEXT,

        total_commits               INTEGER,
        total_committers            INTEGER,
        past_year_commits           INTEGER,
        past_year_committers        INTEGER,
        past_year_bot_commits       INTEGER,
        past_year_bot_committers    INTEGER,
        dds                         REAL,
        past_year_dds               REAL,
        commits_synced_at           TEXT,

        issues_count                INTEGER,
        prs_count                   INTEGER,
        avg_time_to_close_issue     REAL,
        avg_time_to_close_pr        REAL,
        past_year_issues            INTEGER,
        past_year_prs               INTEGER,
        past_year_issues_closed     INTEGER,
        past_year_prs_closed        INTEGER,
        past_year_prs_merged        INTEGER,
        past_year_bot_issues        INTEGER,
        past_year_bot_prs           INTEGER,
        past_year_avg_time_to_close_issue REAL,
        past_year_avg_time_to_close_pr    REAL,
        issue_maintainers_count     INTEGER,
        active_maintainers_count    INTEGER,
        active_maintainers          TEXT,
        issues_synced_at            TEXT,

        advisories_count            INTEGER,
        unpatched_advisories_count  INTEGER,

        days_since_release  INTEGER,
        days_since_push     INTEGER,
        days_since_commit   INTEGER,
        bucket              TEXT,
        signals             TEXT,
        classified_at       TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_repos_bucket ON repos(bucket);
      CREATE INDEX IF NOT EXISTS idx_repos_host   ON repos(host, owner);
    SQL
  end
end
