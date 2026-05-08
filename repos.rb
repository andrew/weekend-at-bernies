#!/usr/bin/env ruby
# Refresh repo metadata (pushed_at, archived, stars, ...) directly from
# repos.ecosyste.ms. The repo_metadata embedded in the packages API can lag
# badly, so this gives a fresher view before classification. Cached under
# cache/repos.
#
# Usage: ruby repos.rb [LIMIT]

require "sqlite3"
require "fileutils"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "repos")
CONN    = conn("https://repos.ecosyste.ms")
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
  WHERE repos_synced_at IS NULL
  ORDER BY (host='github.com') DESC, repository_url
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{urls.size} repos to refresh from repos.ecosyste.ms"

upd = db.prepare <<~SQL
  UPDATE repos SET
    stars=COALESCE(?,stars), forks=COALESCE(?,forks), open_issues=COALESCE(?,open_issues),
    archived=COALESCE(?,archived), fork=COALESCE(?,fork), repo_status=COALESCE(?,repo_status),
    has_issues=COALESCE(?,has_issues), prs_enabled=COALESCE(?,prs_enabled),
    language=COALESCE(?,language), license=COALESCE(?,license),
    default_branch=COALESCE(?,default_branch), repo_created_at=COALESCE(?,repo_created_at),
    pushed_at=COALESCE(?,pushed_at), repos_synced_at=?
  WHERE repository_url=?
SQL

b = ->(v) { v.nil? ? nil : (v ? 1 : 0) }
hit = miss = 0
urls.each_with_index do |url, i|
  m = lookup(url)
  if m.nil?
    miss += 1
  else
    upd.execute(
      m["stargazers_count"], m["forks_count"], m["open_issues_count"],
      b[m["archived"]], b[m["fork"]], m["status"],
      b[m["has_issues"]], b[m["pull_requests_enabled"]],
      m["language"], m["license"], m["default_branch"], m["created_at"],
      m["pushed_at"], m["last_synced_at"],
      url
    )
    hit += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "refreshed #{hit}, no data for #{miss}"
