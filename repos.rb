#!/usr/bin/env ruby
# Refresh repo metadata (pushed_at, archived, stars, ...) directly from
# repos.ecosyste.ms. The repo_metadata embedded in the packages API can lag
# badly, so this gives a fresher view before classification. Cached under
# cache/repos.
#
# Usage: ruby repos.rb [--refresh] [--failures FILE] [LIMIT]

require "sqlite3"
require "fileutils"
require "optparse"
require_relative "http"
require_relative "database"
require_relative "lookup_failures"

WORKDIR = __dir__
DB_PATH = Bernies.database_path
CACHE   = File.join(WORKDIR, "cache", "repos")
CONN    = conn("https://repos.ecosyste.ms")
options = {}
OptionParser.new do |parser|
  parser.on("--refresh") { options[:refresh] = true }
  parser.on("--failures FILE") { |path| options[:failures] = path }
end.parse!
REFRESH = !!options[:refresh]
LIMIT   = ARGV[0]&.to_i

FileUtils.mkdir_p(CACHE)

def lookup(repo_url, refresh: REFRESH)
  result = cached_response(CONN, "/api/v1/repositories/lookup", { url: repo_url }, CACHE, refresh: refresh)
  return result unless result.status == 404

  host = github_repository_response(repo_url, CACHE, refresh: refresh)
  return result unless host

  if host.data && host.data != repo_url
    result = cached_response(CONN, "/api/v1/repositories/lookup", { url: host.data }, CACHE, refresh: refresh)
    result.resolved_url = host.data
  end
  result.host_status = host.status
  if result.status == 404
    result.reason = if host.status == 404
      "repository_not_found"
    elsif host.data && host.status == 200
      "repository_service_miss"
    elsif host.data
      "not_found"
    else
      "host_#{host.reason}"
    end
  end
  result
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
failures = Bernies::LookupFailures.new(db, "repos")

urls = db.execute(<<~SQL).map { |r| r["repository_url"] }
  SELECT repository_url FROM repos
  #{unless REFRESH
    "WHERE repos_synced_at IS NULL OR EXISTS (SELECT 1 FROM lookup_failures f " \
      "WHERE f.collector='repos' AND f.kind='repository' AND f.identifier=repos.repository_url)"
  end}
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
  result = lookup(url, refresh: REFRESH || failures.recorded?("repository", url))
  m = result.data
  if !m.is_a?(Hash) || m.empty? || m.key?("error")
    miss += 1
    puts ; puts "miss: #{failures.record('repository', url, result, repository_url: url)}"
  else
    upd.execute(
      m["stargazers_count"], m["forks_count"], m["open_issues_count"],
      b[m["archived"]], b[m["fork"]], m["status"],
      b[m["has_issues"]], b[m["pull_requests_enabled"]],
      m["language"], m["license"], m["default_branch"], m["created_at"],
      m["pushed_at"], m["last_synced_at"],
      url
    )
    failures.clear("repository", url)
    hit += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "refreshed #{hit}, no data for #{miss}"
Bernies::LookupFailures.export(db, options[:failures], collector: "repos") if options[:failures]
