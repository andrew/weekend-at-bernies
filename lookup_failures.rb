require "csv"
require "fileutils"
require "time"

module Bernies
  class LookupFailures
    COLUMNS = %w[collector kind identifier repository_url packages endpoint http_status host_status resolved_url reason checked_at].freeze

    def initialize(db, collector)
      @db = db
      @collector = collector
      @db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS lookup_failures (
          collector TEXT NOT NULL,
          kind TEXT NOT NULL,
          identifier TEXT NOT NULL,
          repository_url TEXT,
          endpoint TEXT,
          http_status INTEGER,
          host_status INTEGER,
          resolved_url TEXT,
          reason TEXT NOT NULL,
          checked_at TEXT NOT NULL,
          PRIMARY KEY (collector, kind, identifier)
        )
      SQL
    end

    def record(kind, identifier, result, repository_url: nil)
      values = [@collector, kind, identifier, repository_url, result.url, result.status,
                result.host_status, result.resolved_url, result.reason || "invalid_response", Time.now.utc.iso8601]
      @db.execute(<<~SQL, values)
        INSERT INTO lookup_failures
          (collector, kind, identifier, repository_url, endpoint, http_status, host_status, resolved_url, reason, checked_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(collector, kind, identifier) DO UPDATE SET
          repository_url=excluded.repository_url, endpoint=excluded.endpoint,
          http_status=excluded.http_status, host_status=excluded.host_status,
          resolved_url=excluded.resolved_url, reason=excluded.reason, checked_at=excluded.checked_at
      SQL
      "#{kind} #{identifier}: #{result.reason || 'invalid_response'} (HTTP #{result.status || 'unavailable'}; #{result.url})"
    end

    def clear(kind, identifier)
      @db.execute("DELETE FROM lookup_failures WHERE collector=? AND kind=? AND identifier=?", [@collector, kind, identifier])
    end

    def recorded?(kind, identifier)
      !!@db.get_first_value("SELECT 1 FROM lookup_failures WHERE collector=? AND kind=? AND identifier=?", [@collector, kind, identifier])
    end

    def self.export(db, path, collector: nil)
      FileUtils.mkdir_p(File.dirname(path))
      CSV.open(path, "w") do |csv|
        csv << COLUMNS
        next unless db.get_first_value("SELECT name FROM sqlite_master WHERE type='table' AND name='lookup_failures'")

        db.execute(<<~SQL, collector ? [collector] : []) do |row|
          SELECT f.*, (SELECT GROUP_CONCAT(p.purl) FROM packages p WHERE p.repository_url=f.repository_url) AS packages
          FROM lookup_failures f
          #{"WHERE collector=?" if collector}
          ORDER BY collector, kind, identifier
        SQL
          csv << row.values_at(*COLUMNS)
        end
      end
    end
  end
end
