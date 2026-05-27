#!/usr/bin/env ruby
# Top dependent packages for each non-active package, from
# packages.ecosyste.ms /dependent_packages. Stores the top-N in a
# dependents table and rolls concentration up to packages as top1_share
# and top5_share (top dependent's downloads / sum of top-N downloads).
# Used by situate.rb to tell few-large from broad.
#
# Cached under cache/dependents.
#
# Usage: ruby dependents.rb [LIMIT] [--all]

require "sqlite3"
require "fileutils"
require "time"
require "erb"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "dependents")
CONN    = conn("https://packages.ecosyste.ms")
LIMIT   = ARGV.grep(/\A\d+\z/).first&.to_i
ALL     = ARGV.include?("--all")
ECO     = (i = ARGV.index("--ecosystem")) && ARGV[i + 1]
TOP_N   = 20

FileUtils.mkdir_p(CACHE)

def enc(s) = ERB::Util.url_encode(s.to_s)

def fetch_dependents(registry, name)
  path = "/api/v1/registries/#{registry}/packages/#{enc(name)}/dependent_packages"
  cached_get(CONN, path, { per_page: TOP_N, sort: "downloads" }, CACHE)
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS dependents (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    purl                TEXT NOT NULL,
    rank                INTEGER NOT NULL,
    dependent_purl      TEXT,
    dependent_ecosystem TEXT,
    dependent_name      TEXT NOT NULL,
    dependent_downloads INTEGER,
    dependent_repos     INTEGER,
    description         TEXT,
    fetched_at          TEXT NOT NULL,
    UNIQUE(purl, rank)
  );
  CREATE INDEX IF NOT EXISTS idx_dependents_purl ON dependents(purl);
SQL
{ top1_share: "REAL", top5_share: "REAL", top1_dependent: "TEXT", dependents_synced_at: "TEXT" }.each do |c, t|
  db.execute("ALTER TABLE packages ADD COLUMN #{c} #{t}") rescue SQLite3::SQLException
end

bucket_filter = ALL ? "" : "AND (r.bucket IS NULL OR r.bucket <> 'active')"
eco_filter    = ECO ? "AND p.ecosystem = '#{ECO}'" : ""
pkgs = db.execute(<<~SQL)
  SELECT p.purl, p.registry, p.ecosystem, p.name
  FROM packages p LEFT JOIN repos r ON p.repository_url = r.repository_url
  WHERE p.dependents_synced_at IS NULL #{bucket_filter} #{eco_filter}
  ORDER BY p.dependent_repos DESC
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{pkgs.size} packages to fetch dependents for"

ins = db.prepare <<~SQL
  INSERT INTO dependents
    (purl, rank, dependent_purl, dependent_ecosystem, dependent_name,
     dependent_downloads, dependent_repos, description, fetched_at)
  VALUES (?,?,?,?,?,?,?,?,?)
  ON CONFLICT(purl, rank) DO UPDATE SET
    dependent_purl=excluded.dependent_purl, dependent_ecosystem=excluded.dependent_ecosystem,
    dependent_name=excluded.dependent_name, dependent_downloads=excluded.dependent_downloads,
    dependent_repos=excluded.dependent_repos, description=excluded.description,
    fetched_at=excluded.fetched_at
SQL
upd = db.prepare <<~SQL
  UPDATE packages SET top1_share=?, top5_share=?, top1_dependent=?, dependents_synced_at=? WHERE purl=?
SQL

now = Time.now.utc.iso8601
hit = miss = 0
pkgs.each_with_index do |p, i|
  list = fetch_dependents(p["registry"], p["name"])
  if list.nil?
    upd.execute(nil, nil, nil, now, p["purl"])
    miss += 1
  else
    list = list.sort_by { |d| -(d["downloads"] || 0) }.first(TOP_N)
    dls  = list.map { |d| d["downloads"] || 0 }
    sum  = dls.sum
    top1 = sum > 0 ? dls[0].to_f / sum : nil
    top5 = sum > 0 ? dls.first(5).sum.to_f / sum : nil
    list.each_with_index do |d, rank|
      ins.execute(
        p["purl"], rank + 1, d["purl"], d["ecosystem"], d["name"],
        d["downloads"], d["dependent_repos_count"],
        (d["description"] || "")[0, 200], now
      )
    end
    upd.execute(top1, top5, list.dig(0, "name"), now, p["purl"])
    hit += 1
  end
  print "\r[#{i + 1}/#{pkgs.size}] hit=#{hit} miss=#{miss}"
end
ins.close
upd.close
puts
puts "fetched dependents for #{hit}, no data for #{miss}"
