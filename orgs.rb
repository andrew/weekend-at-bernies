#!/usr/bin/env ruby
# For each organisation account holding at least one bernie, ask whether
# anyone is currently maintaining anything under it:
#
#   issues.ecosyste.ms /owners/{org}/maintainers
#     - full maintainer list with interaction counts (bus factor)
#     - active_maintainers list (who's currently doing maintenance)
#
#   repos.ecosyste.ms /owners/{org}/repositories?sort=pushed_at
#     - most recently pushed repo in the org
#     - count of org repos pushed in the last 30 / 365 days
#
# Bots get excluded from the human-active count so a corporate org whose top
# maintainer is renovate-bot or dependabot doesn't look healthier than it is.
#
# Cached under cache/orgs/{maintainers,repos}/.
#
# Usage: ruby orgs.rb [--refresh] [LIMIT]

require_relative "database"

require "sqlite3"
require "set"
require "json"
require "time"
require "fileutils"
require "optparse"
require_relative "http"

WORKDIR           = __dir__
DB_PATH           = Bernies.database_path
MAINTAINERS_CACHE = File.join(WORKDIR, "cache", "orgs", "maintainers")
REPOS_CACHE       = File.join(WORKDIR, "cache", "orgs", "repos")
ISSUES_CONN       = conn("https://issues.ecosyste.ms")
REPOS_CONN        = conn("https://repos.ecosyste.ms")
options = {}
OptionParser.new { |parser| parser.on("--refresh") { options[:refresh] = true } }.parse!
REFRESH = !!options[:refresh]
LIMIT = ARGV[0]&.to_i

# Known bot accounts that show up as "maintainers" in issue activity.
# This list is conservative; the regex catches the long tail.
KNOWN_BOTS = %w[
  renovate-bot renovate dependabot mergify mergify-bot github-actions
  modular-magician imgbot snyk-bot whitesource whitesource-bolt-for-github
  allcontributors stale stale-bot codecov codecov-bot codecov-io
  googleapis-publisher google-cla googlebot
  semantic-release-bot greenkeeper greenkeeperio-bot
  ghaction-import-gpg pull renovatebot
].to_set

BOT_REGEX = /\A.+\[bot\]\z|-bot\z|\Abot-|^github-actions/i

def bot?(login)
  return false if login.nil? || login.empty?
  KNOWN_BOTS.include?(login.downcase) || login =~ BOT_REGEX ? true : false
end

FileUtils.mkdir_p(MAINTAINERS_CACHE)
FileUtils.mkdir_p(REPOS_CACHE)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS org_activity (
    host                          TEXT NOT NULL,
    login                         TEXT NOT NULL,
    maintainer_count              INTEGER,
    active_maintainer_count       INTEGER,
    human_active_maintainer_count INTEGER,
    top_maintainer                TEXT,
    top_maintainer_count          INTEGER,
    top_is_bot                    INTEGER,
    top1_share                    REAL,
    top_human_maintainer          TEXT,
    top_human_count               INTEGER,
    most_recent_push_repo         TEXT,
    most_recent_push_at           TEXT,
    recently_pushed_30d           INTEGER,
    recently_pushed_365d          INTEGER,
    maintainers_synced            INTEGER NOT NULL DEFAULT 0,
    repos_synced                  INTEGER NOT NULL DEFAULT 0,
    org_synced_at                 TEXT,
    PRIMARY KEY (host, login)
  );
  CREATE INDEX IF NOT EXISTS idx_org_activity_active
    ON org_activity(human_active_maintainer_count);
SQL

def fetch_org_maintainers(login)
  cached_get(
    ISSUES_CONN,
    "/api/v1/hosts/GitHub/owners/#{login}/maintainers",
    {},
    MAINTAINERS_CACHE, refresh: REFRESH
  )
end

def fetch_org_pushes(login)
  cached_get(
    REPOS_CONN,
    "/api/v1/hosts/GitHub/owners/#{login}/repositories",
    { sort: "pushed_at", order: "desc", per_page: 100 },
    REPOS_CACHE, refresh: REFRESH
  )
end

rows = db.execute(<<~SQL).map { |r| r["login"] }
  SELECT DISTINCT o.login FROM owners o
  JOIN repos r ON r.host=o.host AND r.owner=o.login
  WHERE o.kind='organization' AND o.host='github.com'
    AND r.bucket IN ('dead','dormant')
  ORDER BY o.login
SQL

done = db
  .execute("SELECT login FROM org_activity WHERE maintainers_synced=1 AND repos_synced=1")
  .map { |r| r["login"] }
  .to_set

todo = REFRESH ? rows : rows.reject { |l| done.include?(l) }
todo = todo.first(LIMIT) if LIMIT
puts "#{todo.size} orgs to fetch (#{done.size} already done)"

upsert = db.prepare <<~SQL
  INSERT INTO org_activity (
    host, login,
    maintainer_count, active_maintainer_count, human_active_maintainer_count,
    top_maintainer, top_maintainer_count, top_is_bot, top1_share,
    top_human_maintainer, top_human_count,
    most_recent_push_repo, most_recent_push_at,
    recently_pushed_30d, recently_pushed_365d,
    maintainers_synced, repos_synced, org_synced_at
  ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,datetime('now'))
  ON CONFLICT(host, login) DO UPDATE SET
    #{%w[maintainer_count active_maintainer_count human_active_maintainer_count top_maintainer top_maintainer_count top_is_bot top1_share top_human_maintainer top_human_count].map { |c|
      "#{c}=CASE WHEN excluded.maintainers_synced=1 THEN excluded.#{c} ELSE org_activity.#{c} END"
    }.join(",")},
    #{%w[most_recent_push_repo most_recent_push_at recently_pushed_30d recently_pushed_365d].map { |c|
      "#{c}=CASE WHEN excluded.repos_synced=1 THEN excluded.#{c} ELSE org_activity.#{c} END"
    }.join(",")},
    maintainers_synced=excluded.maintainers_synced,
    repos_synced=excluded.repos_synced,
    org_synced_at=CASE WHEN excluded.maintainers_synced=1 OR excluded.repos_synced=1
      THEN excluded.org_synced_at ELSE org_activity.org_synced_at END
SQL

now      = Time.now
days_30  = now - 30 * 86_400
days_365 = now - 365 * 86_400

def safe_time(s)
  Time.parse(s)
rescue ArgumentError, TypeError
  nil
end

mh = ph = both_miss = 0
todo.each_with_index do |login, i|
  mdata = fetch_org_maintainers(login)
  pdata = fetch_org_pushes(login)
  mdata = nil unless mdata.is_a?(Hash)
  pdata = nil unless pdata.is_a?(Array)

  m_all    = mdata && mdata["maintainers"].is_a?(Array) ? mdata["maintainers"] : []
  m_active = mdata && mdata["active_maintainers"].is_a?(Array) ? mdata["active_maintainers"] : []
  human_active = m_active.reject { |m| bot?(m["maintainer"]) }
  top = m_all.first
  top_human = m_all.find { |m| !bot?(m["maintainer"]) }
  total_counts = m_all.sum { |m| (m["count"] || 0).to_i }
  top1_share = top && total_counts > 0 ? (top["count"].to_f / total_counts).round(3) : nil

  push_repos = pdata.is_a?(Array) ? pdata : []
  most_recent = push_repos.first
  push_30  = push_repos.count { |r| (t = safe_time(r["pushed_at"])) && t >= days_30 }
  push_365 = push_repos.count { |r| (t = safe_time(r["pushed_at"])) && t >= days_365 }

  maintainers_synced = mdata.nil? ? 0 : 1
  repos_synced       = pdata.nil? ? 0 : 1
  both_miss += 1 if maintainers_synced == 0 && repos_synced == 0

  upsert.execute(
    "github.com", login,
    m_all.size, m_active.size, human_active.size,
    top && top["maintainer"], top && top["count"],
    top && bot?(top["maintainer"]) ? 1 : 0,
    top1_share,
    top_human && top_human["maintainer"], top_human && top_human["count"],
    most_recent && most_recent["full_name"],
    most_recent && most_recent["pushed_at"],
    push_30, push_365,
    maintainers_synced, repos_synced
  )
  mh += 1 if maintainers_synced == 1
  ph += 1 if repos_synced == 1
  print "\r[#{i + 1}/#{todo.size}] maint=#{mh} repos=#{ph} both_miss=#{both_miss}"
end
upsert.close
puts
puts "org_activity populated: #{db.get_first_value("SELECT COUNT(*) FROM org_activity")}"
