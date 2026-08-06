#!/usr/bin/env ruby
# For each individual owner of a non-active critical package, ask the
# ecosyste.ms services whether the person is still doing anything visible:
#
#   issues.ecosyste.ms /authors/{login}
#     - active_maintaining: repositories where the user is currently engaged
#       on issues/PRs (strongest "still here" signal)
#     - maintaining: historical maintenance footprint
#
#   repos.ecosyste.ms /owners/{login}/repositories?sort=pushed_at
#     - most recently pushed repo across everything they own
#     - count of their repos pushed within the last 30 / 365 days
#
# Scoped to github.com individuals who hold at least one dead/dormant repo
# in the critical set. Cached under cache/maintainers/{issues,repos}/.
#
# Usage: ruby maintainers.rb [LIMIT]

require "sqlite3"
require "set"
require "json"
require "time"
require "fileutils"
require_relative "http"
require_relative "database"

WORKDIR      = __dir__
DB_PATH      = Bernies.database_path
ISSUES_CACHE = File.join(WORKDIR, "cache", "maintainers", "issues")
REPOS_CACHE  = File.join(WORKDIR, "cache", "maintainers", "repos")
ISSUES_CONN  = conn("https://issues.ecosyste.ms")
REPOS_CONN   = conn("https://repos.ecosyste.ms")
LIMIT        = ARGV[0]&.to_i

FileUtils.mkdir_p(ISSUES_CACHE)
FileUtils.mkdir_p(REPOS_CACHE)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS maintainers (
    host                       TEXT NOT NULL,
    login                      TEXT NOT NULL,
    issues_count               INTEGER,
    pull_requests_count        INTEGER,
    merged_pull_requests_count INTEGER,
    maintaining_count          INTEGER,
    active_maintaining_count   INTEGER,
    active_maintaining         TEXT,
    most_recent_push_repo      TEXT,
    most_recent_push_at        TEXT,
    recently_pushed_30d        INTEGER,
    recently_pushed_365d       INTEGER,
    issues_synced              INTEGER NOT NULL DEFAULT 0,
    repos_synced               INTEGER NOT NULL DEFAULT 0,
    maintainers_synced_at      TEXT,
    PRIMARY KEY (host, login)
  );
  CREATE INDEX IF NOT EXISTS idx_maintainers_active
    ON maintainers(active_maintaining_count);
SQL

def fetch_author(login)
  cached_get(
    ISSUES_CONN,
    "/api/v1/hosts/GitHub/authors/#{login}",
    {},
    ISSUES_CACHE
  )
end

def fetch_recent_pushes(login)
  cached_get(
    REPOS_CONN,
    "/api/v1/hosts/GitHub/owners/#{login}/repositories",
    { sort: "pushed_at", order: "desc", per_page: 100 },
    REPOS_CACHE
  )
end

rows = db.execute(<<~SQL).map { |r| r["login"] }
  SELECT DISTINCT o.login FROM owners o
  JOIN repos r ON r.host=o.host AND r.owner=o.login
  WHERE o.kind='user' AND o.host='github.com'
    AND r.bucket IN ('dead','dormant')
  ORDER BY o.login
SQL

done = db
  .execute("SELECT login FROM maintainers WHERE issues_synced=1 AND repos_synced=1")
  .map { |r| r["login"] }
  .to_set

todo = rows.reject { |l| done.include?(l) }
todo = todo.first(LIMIT) if LIMIT
puts "#{todo.size} maintainers to fetch (#{done.size} already done)"

upsert = db.prepare <<~SQL
  INSERT INTO maintainers (
    host, login,
    issues_count, pull_requests_count, merged_pull_requests_count,
    maintaining_count, active_maintaining_count, active_maintaining,
    most_recent_push_repo, most_recent_push_at,
    recently_pushed_30d, recently_pushed_365d,
    issues_synced, repos_synced, maintainers_synced_at
  ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,datetime('now'))
  ON CONFLICT(host, login) DO UPDATE SET
    issues_count=excluded.issues_count,
    pull_requests_count=excluded.pull_requests_count,
    merged_pull_requests_count=excluded.merged_pull_requests_count,
    maintaining_count=excluded.maintaining_count,
    active_maintaining_count=excluded.active_maintaining_count,
    active_maintaining=excluded.active_maintaining,
    most_recent_push_repo=excluded.most_recent_push_repo,
    most_recent_push_at=excluded.most_recent_push_at,
    recently_pushed_30d=excluded.recently_pushed_30d,
    recently_pushed_365d=excluded.recently_pushed_365d,
    issues_synced=excluded.issues_synced,
    repos_synced=excluded.repos_synced,
    maintainers_synced_at=datetime('now')
SQL

now      = Time.now
days_30  = now - 30 * 86_400
days_365 = now - 365 * 86_400

def safe_time(s)
  Time.parse(s)
rescue ArgumentError, TypeError
  nil
end

issues_hit = repos_hit = both_miss = 0
todo.each_with_index do |login, i|
  author = fetch_author(login)
  repos  = fetch_recent_pushes(login)

  am = author && author["active_maintaining"].is_a?(Array) ? author["active_maintaining"] : []
  am_top = am.first(10).map { |r| { repo: r["repository"], count: r["count"] } }
  maintaining_count = author && author["maintaining"].is_a?(Array) ? author["maintaining"].size : nil

  push_repos = repos.is_a?(Array) ? repos : []
  most_recent = push_repos.first
  push_30  = push_repos.count { |r| (t = safe_time(r["pushed_at"])) && t >= days_30 }
  push_365 = push_repos.count { |r| (t = safe_time(r["pushed_at"])) && t >= days_365 }

  issues_synced = author.nil? ? 0 : 1
  repos_synced  = repos.nil?  ? 0 : 1
  both_miss += 1 if issues_synced == 0 && repos_synced == 0

  upsert.execute(
    "github.com", login,
    author && author["issues_count"],
    author && author["pull_requests_count"],
    author && author["merged_pull_requests_count"],
    maintaining_count,
    am.size,
    am_top.to_json,
    most_recent && most_recent["full_name"],
    most_recent && most_recent["pushed_at"],
    push_30, push_365,
    issues_synced, repos_synced
  )
  issues_hit += 1 if issues_synced == 1
  repos_hit  += 1 if repos_synced == 1
  print "\r[#{i + 1}/#{todo.size}] issues=#{issues_hit} repos=#{repos_hit} both_miss=#{both_miss}"
end
upsert.close
puts
puts "maintainers populated: #{db.get_first_value("SELECT COUNT(*) FROM maintainers")}"
