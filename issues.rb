#!/usr/bin/env ruby
# Enrich repos with issues.ecosyste.ms: issue/PR counts, close times,
# past-year activity, and the maintainers / active_maintainers lists
# (people with MEMBER/OWNER/COLLABORATOR association who interacted).
# Cached under cache/issues.
#
# Usage: ruby issues.rb [LIMIT]

require "sqlite3"
require "fileutils"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "issues")
CONN    = conn("https://issues.ecosyste.ms")
LIMIT   = ARGV[0]&.to_i

FileUtils.mkdir_p(CACHE)

def lookup(repo_url)
  cached_get(CONN, "/api/v1/repositories/lookup", { url: repo_url }, CACHE)
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

urls = db.execute(<<~SQL).map { |r| r["repository_url"] }
  SELECT repository_url FROM repos
  WHERE issues_synced_at IS NULL
  ORDER BY (host='github.com') DESC, repository_url
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{urls.size} repos to enrich from issues.ecosyste.ms"

upd = db.prepare <<~SQL
  UPDATE repos SET
    issues_count=?, prs_count=?,
    avg_time_to_close_issue=?, avg_time_to_close_pr=?,
    past_year_issues=?, past_year_prs=?,
    past_year_issues_closed=?, past_year_prs_closed=?, past_year_prs_merged=?,
    past_year_bot_issues=?, past_year_bot_prs=?,
    past_year_avg_time_to_close_issue=?, past_year_avg_time_to_close_pr=?,
    issue_maintainers_count=?, active_maintainers_count=?, active_maintainers=?,
    issues_synced_at=?
  WHERE repository_url=?
SQL

hit = miss = 0
urls.each_with_index do |url, i|
  m = lookup(url)
  if m.nil?
    miss += 1
  else
    active = (m["active_maintainers"] || []).map { |a| a["login"] }.compact
    upd.execute(
      m["issues_count"], m["pull_requests_count"],
      m["avg_time_to_close_issue"], m["avg_time_to_close_pull_request"],
      m["past_year_issues_count"], m["past_year_pull_requests_count"],
      m["past_year_issues_closed_count"], m["past_year_pull_requests_closed_count"],
      m["past_year_merged_pull_requests_count"],
      m["past_year_bot_issues_count"], m["past_year_bot_pull_requests_count"],
      m["past_year_avg_time_to_close_issue"], m["past_year_avg_time_to_close_pull_request"],
      (m["maintainers"] || []).size, active.size, active.join(","),
      m["last_synced_at"],
      url
    )
    hit += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "enriched #{hit}, no data for #{miss}"
