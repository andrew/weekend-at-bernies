#!/usr/bin/env ruby
# Fetch security advisories per package from advisories.ecosyste.ms and
# record whether a patched version exists. The headline number for the talk
# is dead/dormant packages with unpatched advisories: there is a known
# vulnerability and nobody who can ship the fix.
#
# Populates the advisories table (one row per advisory x package) and rolls
# counts up to repos.advisories_count / repos.unpatched_advisories_count.
# Cached under cache/advisories.
#
# Usage: ruby advisories.rb [LIMIT]

require "sqlite3"
require "fileutils"
require "time"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "advisories")
CONN    = conn("https://advisories.ecosyste.ms")
LIMIT   = ARGV[0]&.to_i

FileUtils.mkdir_p(CACHE)

def fetch(ecosystem, name)
  cached_get(CONN, "/api/v1/advisories", { ecosystem: ecosystem, package_name: name, per_page: 100 }, CACHE) || []
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS advisories (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    purl            TEXT NOT NULL,
    ecosystem       TEXT NOT NULL,
    package_name    TEXT NOT NULL,
    repository_url  TEXT,
    identifier      TEXT NOT NULL,
    title           TEXT,
    severity        TEXT,
    cvss_score      REAL,
    published_at    TEXT,
    withdrawn_at    TEXT,
    vulnerable_range      TEXT,
    first_patched_version TEXT,
    patched         INTEGER NOT NULL,
    url             TEXT,
    fetched_at      TEXT NOT NULL,
    UNIQUE(purl, identifier)
  );
  CREATE INDEX IF NOT EXISTS idx_adv_repo    ON advisories(repository_url);
  CREATE INDEX IF NOT EXISTS idx_adv_patched ON advisories(patched);
SQL

pkgs = db.execute(<<~SQL)
  SELECT purl, ecosystem, name, repository_url FROM packages
  ORDER BY ecosystem, name
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{pkgs.size} packages to check for advisories"

ins = db.prepare <<~SQL
  INSERT INTO advisories
    (purl, ecosystem, package_name, repository_url, identifier, title, severity,
     cvss_score, published_at, withdrawn_at, vulnerable_range, first_patched_version,
     patched, url, fetched_at)
  VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
  ON CONFLICT(purl, identifier) DO UPDATE SET
    severity=excluded.severity, cvss_score=excluded.cvss_score,
    withdrawn_at=excluded.withdrawn_at, vulnerable_range=excluded.vulnerable_range,
    first_patched_version=excluded.first_patched_version, patched=excluded.patched,
    fetched_at=excluded.fetched_at
SQL

now = Time.now.utc.iso8601
total = 0
unpatched = 0
pkgs.each_with_index do |p, i|
  advs = fetch(p["ecosystem"], p["name"])
  advs.each do |a|
    next if a["withdrawn_at"]
    ident = (a["identifiers"] || []).first || a["uuid"]
    entry = (a["packages"] || []).find { |ap| ap["ecosystem"] == p["ecosystem"] && ap["package_name"].to_s.downcase == p["name"].to_s.downcase }
    versions = entry ? (entry["versions"] || []) : []
    ranges  = versions.map { |v| v["vulnerable_version_range"] }.compact.join("; ")
    patched_versions = versions.map { |v| v["first_patched_version"] }
    has_patch = !patched_versions.empty? && patched_versions.all? { |v| v && !v.to_s.empty? }
    ins.execute(
      p["purl"], p["ecosystem"], p["name"], p["repository_url"],
      ident, a["title"], a["severity"], a["cvss_score"],
      a["published_at"], a["withdrawn_at"], ranges,
      patched_versions.compact.join("; "),
      has_patch ? 1 : 0, a["url"], now
    )
    total += 1
    unpatched += 1 unless has_patch
  end
  print "\r[#{i + 1}/#{pkgs.size}] advisories=#{total} unpatched=#{unpatched}"
end
ins.close
puts

db.execute_batch <<~SQL
  UPDATE repos SET
    advisories_count = (
      SELECT COUNT(DISTINCT identifier) FROM advisories a
      WHERE a.repository_url = repos.repository_url AND a.withdrawn_at IS NULL
    ),
    unpatched_advisories_count = (
      SELECT COUNT(DISTINCT identifier) FROM advisories a
      WHERE a.repository_url = repos.repository_url AND a.withdrawn_at IS NULL AND a.patched = 0
    );
SQL

n = db.get_first_value("SELECT COUNT(*) FROM advisories")
u = db.get_first_value("SELECT COUNT(*) FROM advisories WHERE patched=0")
r = db.get_first_value("SELECT COUNT(*) FROM repos WHERE unpatched_advisories_count > 0")
puts "#{n} advisory rows, #{u} unpatched, #{r} repos with at least one unpatched advisory"
