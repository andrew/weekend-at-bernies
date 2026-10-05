#!/usr/bin/env ruby
# Top dependent packages for each non-active package, from
# packages.ecosyste.ms /dependent_packages. Stores the top-N in a
# dependents table and rolls concentration up to packages as top1_share
# and top5_share (top dependent's downloads / sum of top-N downloads).
# Used by situate.rb to tell few-large from broad.
#
# Cached under cache/dependents.
#
# Usage: ruby dependents.rb [--refresh] [--all] [--ecosystem NAME] [LIMIT]

require_relative "database"

require "sqlite3"
require "fileutils"
require "time"
require "erb"
require "optparse"
require_relative "http"

WORKDIR = __dir__
DB_PATH = Bernies.database_path
CACHE   = File.join(WORKDIR, "cache", "dependents")
CONN    = conn("https://packages.ecosyste.ms")
options = {}
OptionParser.new do |parser|
  parser.on("--refresh") { options[:refresh] = true }
  parser.on("--all") { options[:all] = true }
  parser.on("--ecosystem NAME") { |name| options[:ecosystem] = name }
end.parse!
REFRESH = !!options[:refresh]
ALL = !!options[:all]
ECO = options[:ecosystem]
LIMIT = ARGV[0]&.to_i
TOP_N   = 20

FileUtils.mkdir_p(CACHE)

def enc(s) = ERB::Util.url_encode(s.to_s)

NO_DOWNLOADS = %w[proxy.golang.org repo1.maven.org swiftpackageindex.com]

def fetch_dependents(registry, name)
  sort = NO_DOWNLOADS.include?(registry) ? "dependent_repos_count" : "downloads"
  path = "/api/v1/registries/#{registry}/packages/#{enc(name)}/dependent_packages"
  cached_get(CONN, path, { per_page: TOP_N, sort: sort }, CACHE, refresh: REFRESH)
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
{ top1_share: "REAL", top5_share: "REAL", top1_dependent: "TEXT",
  transit_ratio: "REAL", dependents_synced_at: "TEXT" }.each do |c, t|
  db.execute("ALTER TABLE packages ADD COLUMN #{c} #{t}") rescue SQLite3::SQLException
end

bucket_filter = ALL ? "" : "AND (r.bucket IS NULL OR r.bucket <> 'active')"
eco_filter    = ECO ? "AND p.ecosystem = '#{ECO}'" : ""
pkgs = db.execute(<<~SQL)
  SELECT p.purl, p.registry, p.ecosystem, p.name, p.downloads, p.dependent_repos
  FROM packages p LEFT JOIN repos r ON p.repository_url = r.repository_url
  WHERE #{REFRESH ? "1=1" : "p.dependents_synced_at IS NULL"} #{bucket_filter} #{eco_filter}
  ORDER BY p.dependent_packages ASC NULLS LAST
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
  UPDATE packages SET top1_share=?, top5_share=?, top1_dependent=?, transit_ratio=?, dependents_synced_at=? WHERE purl=?
SQL

now = Time.now.utc.iso8601
hit = miss = 0
pkgs.each_with_index do |p, i|
  list = fetch_dependents(p["registry"], p["name"])
  if !list.is_a?(Array)
    miss += 1
  else
    use_dl = p["downloads"] && p["downloads"] > 0
    metric = use_dl ? "downloads" : "dependent_repos_count"
    own    = use_dl ? p["downloads"] : p["dependent_repos"]
    list = list.reject { |d| d["name"] == p["name"] }
               .sort_by { |d| -(d[metric] || 0) }.first(TOP_N)
    vals = list.map { |d| d[metric] || 0 }
    sum  = vals.sum
    top1 = sum > 0 ? vals[0].to_f / sum : nil
    top5 = sum > 0 ? vals.first(5).sum.to_f / sum : nil
    transit = (own && own > 0) ? (sum.to_f / own).round(3) : nil
    db.transaction do
      db.execute("DELETE FROM dependents WHERE purl=?", [p["purl"]])
      list.each_with_index do |d, rank|
        ins.execute(
          p["purl"], rank + 1, d["purl"], d["ecosystem"], d["name"],
          d["downloads"], d["dependent_repos_count"],
          (d["description"] || "")[0, 200], now
        )
      end
      upd.execute(top1, top5, list.dig(0, "name"), transit, now, p["purl"])
    end
    hit += 1
  end
  print "\r[#{i + 1}/#{pkgs.size}] hit=#{hit} miss=#{miss}"
end
ins.close
upd.close
puts
puts "fetched dependents for #{hit}, no data for #{miss}"
