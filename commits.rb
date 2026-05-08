#!/usr/bin/env ruby
# Enrich repos with commits.ecosyste.ms: total/past-year commit and committer
# counts, bot splits, and dds (development distribution score, a bus-factor
# proxy). Cached under cache/commits.
#
# Usage: ruby commits.rb [LIMIT]

require "sqlite3"
require "fileutils"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "commits")
CONN    = conn("https://commits.ecosyste.ms")
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
  WHERE commits_synced_at IS NULL
  ORDER BY (host='github.com') DESC, repository_url
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{urls.size} repos to enrich from commits.ecosyste.ms"

upd = db.prepare <<~SQL
  UPDATE repos SET
    total_commits=?, total_committers=?,
    past_year_commits=?, past_year_committers=?,
    past_year_bot_commits=?, past_year_bot_committers=?,
    dds=?, past_year_dds=?, commits_synced_at=?
  WHERE repository_url=?
SQL

hit = miss = 0
urls.each_with_index do |url, i|
  m = lookup(url)
  if m.nil?
    miss += 1
  else
    upd.execute(
      m["total_commits"], m["total_committers"],
      m["past_year_total_commits"], m["past_year_total_committers"],
      m["past_year_total_bot_commits"], m["past_year_total_bot_committers"],
      m["dds"], m["past_year_dds"], m["last_synced_at"],
      url
    )
    hit += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "enriched #{hit}, no data for #{miss}"
