#!/usr/bin/env ruby
# Dependency outdatedness: for each package's latest published version, fetch
# its declared dependencies, look up each dep's current latest release, and
# record how many major versions behind the requirement is. Stale deps mean
# the ecosystem has moved on and this package hasn't followed.
#
# This is a drift/risk measure rather than a sign-of-life detector, so by
# default it runs over non-active repos first (where the answer matters).
# Pass --all to cover everything.
#
# Populates the dependencies table and rolls counts up to packages.
#
# Usage: ruby deps.rb [LIMIT] [--all]

require "sqlite3"
require "fileutils"
require "time"
require "erb"
require "thread"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE_V = File.join(WORKDIR, "cache", "versions")
CACHE_L = File.join(WORKDIR, "cache", "latest")
CONN    = conn("https://packages.ecosyste.ms")
LIMIT   = ARGV.reject { |a| a.start_with?("--") }.first&.to_i
ALL     = ARGV.include?("--all")

FileUtils.mkdir_p(CACHE_V)
FileUtils.mkdir_p(CACHE_L)

ECO_REGISTRY = {
  "npm" => "npmjs.org", "pypi" => "pypi.org", "rubygems" => "rubygems.org",
  "cargo" => "crates.io", "go" => "proxy.golang.org", "maven" => "repo1.maven.org",
  "nuget" => "nuget.org", "packagist" => "packagist.org", "pub" => "pub.dev",
  "hex" => "hex.pm", "cocoapods" => "cocoapods.org", "cpan" => "metacpan.org",
  "hackage" => "hackage.haskell.org", "julia" => "juliahub.com",
  "conda" => "conda-forge.org", "swiftpm" => "swiftpackageindex.com"
}

def major_of(v)
  return nil if v.nil?
  s = v.to_s.gsub(/^[^\d]+/, "")
  m = s[/\A(\d+)/, 1]
  m && m.length <= 4 ? m.to_i : nil
end

def enc(s) = ERB::Util.url_encode(s.to_s)

def fetch_version_deps(registry, name, version)
  path = "/api/v1/registries/#{registry}/packages/#{enc(name)}/versions/#{enc(version)}"
  data = cached_get(CONN, path, {}, CACHE_V)
  data && data["dependencies"] || []
end

LATEST = {}
LATEST_MUTEX = Mutex.new
def fetch_latest(ecosystem, name)
  key = "#{ecosystem}/#{name}"
  LATEST_MUTEX.synchronize { return LATEST[key] if LATEST.key?(key) }
  reg = ECO_REGISTRY[ecosystem] or return nil
  data = cached_get(CONN, "/api/v1/registries/#{reg}/packages/#{enc(name)}", {}, CACHE_L)
  v = data && data["latest_release_number"]
  LATEST_MUTEX.synchronize { LATEST[key] = v }
  v
end

def seed_latest_from_db(db)
  db.execute("SELECT ecosystem, name, latest_release FROM packages WHERE latest_release IS NOT NULL") do |r|
    LATEST["#{r['ecosystem']}/#{r['name']}"] = r["latest_release"]
  end
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS dependencies (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    purl          TEXT NOT NULL,
    ecosystem     TEXT NOT NULL,
    package_name  TEXT NOT NULL,
    dep_ecosystem TEXT NOT NULL,
    dep_name      TEXT NOT NULL,
    kind          TEXT,
    requirement   TEXT,
    dep_latest    TEXT,
    req_major     INTEGER,
    latest_major  INTEGER,
    majors_behind INTEGER,
    fetched_at    TEXT NOT NULL,
    UNIQUE(purl, dep_ecosystem, dep_name, kind)
  );
  CREATE INDEX IF NOT EXISTS idx_deps_purl ON dependencies(purl);
  CREATE INDEX IF NOT EXISTS idx_deps_dep  ON dependencies(dep_ecosystem, dep_name);
SQL
%w[runtime_deps runtime_outdated dev_deps dev_outdated max_majors_behind deps_fetched_at].each do |c|
  db.execute("ALTER TABLE packages ADD COLUMN #{c} #{c.end_with?('_at') ? 'TEXT' : 'INTEGER'}") rescue SQLite3::SQLException
end

seed_latest_from_db(db)

bucket_filter = ALL ? "" : "AND (r.bucket IS NULL OR r.bucket <> 'active')"
pkgs = db.execute(<<~SQL)
  SELECT p.purl, p.registry, p.ecosystem, p.name, p.latest_release
  FROM packages p LEFT JOIN repos r ON p.repository_url = r.repository_url
  WHERE p.latest_release IS NOT NULL AND p.deps_fetched_at IS NULL #{bucket_filter}
  ORDER BY p.ecosystem, p.name
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{pkgs.size} packages to check for dependency drift"

ins = db.prepare <<~SQL
  INSERT INTO dependencies
    (purl, ecosystem, package_name, dep_ecosystem, dep_name, kind, requirement,
     dep_latest, req_major, latest_major, majors_behind, fetched_at)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
  ON CONFLICT(purl, dep_ecosystem, dep_name, kind) DO UPDATE SET
    requirement=excluded.requirement, dep_latest=excluded.dep_latest,
    req_major=excluded.req_major, latest_major=excluded.latest_major,
    majors_behind=excluded.majors_behind, fetched_at=excluded.fetched_at
SQL
upd = db.prepare <<~SQL
  UPDATE packages SET runtime_deps=?, runtime_outdated=?, dev_deps=?, dev_outdated=?,
    max_majors_behind=?, deps_fetched_at=? WHERE purl=?
SQL

now = Time.now.utc.iso8601
total_deps = 0
total_outdated = 0

queue = Queue.new
pkgs.each { |p| queue << p }
done = Queue.new

WORKERS = 8
threads = WORKERS.times.map do
  Thread.new do
    while (p = queue.pop(true) rescue nil)
      deps = fetch_version_deps(p["registry"], p["name"], p["latest_release"])
      rows = []
      deps.each do |d|
        next if d["direct"] == false
        eco = d["ecosystem"]
        next unless ECO_REGISTRY.key?(eco)
        latest = fetch_latest(eco, d["package_name"])
        rmaj   = major_of(d["requirements"])
        lmaj   = major_of(latest)
        behind = (rmaj && lmaj) ? [lmaj - rmaj, 0].max : nil
        rows << [eco, d["package_name"], d["kind"], d["requirements"], latest, rmaj, lmaj, behind]
      end
      done << [p, rows]
    end
  end
end

processed = 0
until processed == pkgs.size
  p, rows = done.pop
  rt = rto = dv = dvo = 0
  maxb = nil
  rows.each do |eco, dep_name, kind, req, latest, rmaj, lmaj, behind|
    runtime = (kind.to_s.downcase == "runtime")
    if runtime
      rt += 1; rto += 1 if behind && behind >= 1
    else
      dv += 1; dvo += 1 if behind && behind >= 1
    end
    maxb = behind if behind && (maxb.nil? || behind > maxb)
    ins.execute(p["purl"], p["ecosystem"], p["name"], eco, dep_name, kind, req, latest, rmaj, lmaj, behind, now)
    total_deps += 1
    total_outdated += 1 if behind && behind >= 1
  end
  upd.execute(rt, rto, dv, dvo, maxb, now, p["purl"])
  processed += 1
  print "\r[#{processed}/#{pkgs.size}] deps=#{total_deps} outdated=#{total_outdated}"
end
threads.each(&:join)
ins.close
upd.close
puts
puts "#{total_deps} dependency edges, #{total_outdated} at least one major behind"
