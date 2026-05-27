#!/usr/bin/env ruby
# Heuristic pre-fill of packages.situation for non-active packages, plus
# eol_direct and dead_transitive_count. Thresholds are starting guesses;
# tune against the rubygems set. Anything that doesn't match a rule is
# left null for llm.rb / tag.rb to fill.
#
# dead_transitive_count is currently depth-1 only (direct runtime deps
# whose repo is bucket=dead or archived) since the dependencies table only
# holds direct deps. max_dead_depth is therefore 0 or 1.
#
# Usage: ruby situate.rb [--all]

require "sqlite3"
require "time"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
ALL     = ARGV.include?("--all")

INLINEABLE_LOC        = 300
INLINEABLE_COMPLEXITY = 50
FEW_LARGE_DEPENDENTS  = 20
FEW_LARGE_TOP1        = 0.5
BROAD_DEPENDENTS      = 200
KITCHEN_ENTRIES       = 10
KITCHEN_LOC           = 3000

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
{
  situation: "TEXT", eol_direct: "INTEGER",
  dead_transitive_count: "INTEGER", max_dead_depth: "INTEGER",
  remediation: "TEXT", alternative_purl: "TEXT",
  remediation_notes: "TEXT", remediation_source: "TEXT",
  llm_confidence: "REAL", tagged_at: "TEXT", situated_at: "TEXT"
}.each do |c, t|
  db.execute("ALTER TABLE packages ADD COLUMN #{c} #{t}") rescue SQLite3::SQLException
end

dead_deps = Hash.new(0)
db.execute(<<~SQL).each { |r| dead_deps[r["purl"]] = r["n"] }
  SELECT d.purl, COUNT(*) AS n
  FROM dependencies d
  JOIN packages dp ON dp.ecosystem = d.dep_ecosystem AND dp.name = d.dep_name
  JOIN repos dr ON dr.repository_url = dp.repository_url
  WHERE LOWER(d.kind) = 'runtime' AND (dr.bucket = 'dead' OR dr.archived = 1)
  GROUP BY d.purl
SQL

bucket_filter = ALL ? "" : "AND (r.bucket IS NULL OR r.bucket <> 'active')"
rows = db.execute(<<~SQL)
  SELECT p.purl, p.dependent_packages, p.runtime_deps, p.top1_share,
         r.code_loc, r.complexity, r.entry_points, r.has_native,
         r.archived, r.deprecation_text
  FROM packages p LEFT JOIN repos r ON r.repository_url = p.repository_url
  WHERE 1=1 #{bucket_filter}
SQL

puts "#{rows.size} packages to situate"

def situate(p)
  loc, cx, ep   = p["code_loc"], p["complexity"], p["entry_points"]
  rdeps, top1   = p["runtime_deps"], p["top1_share"]
  ndep          = p["dependent_packages"]

  return "inlineable"  if loc && loc < INLINEABLE_LOC && (cx.nil? || cx < INLINEABLE_COMPLEXITY) && (rdeps || 0) == 0 && p["has_native"] != 1
  return "few-large"   if top1 && top1 > FEW_LARGE_TOP1 && ndep && ndep < FEW_LARGE_DEPENDENTS
  return "few-large"   if top1 && top1 > 0.9
  return "kitchen-sink" if ep && ep > KITCHEN_ENTRIES && loc && loc > KITCHEN_LOC
  return "broad"       if ndep && ndep > BROAD_DEPENDENTS
  return "no-alternative" if p["has_native"] == 1
  nil
end

upd = db.prepare <<~SQL
  UPDATE packages SET situation=?, eol_direct=?, dead_transitive_count=?,
    max_dead_depth=?, remediation_source=COALESCE(remediation_source, ?),
    situated_at=? WHERE purl=?
    AND (remediation_source IS NULL OR remediation_source = 'heuristic')
SQL

now = Time.now.utc.iso8601
counts = Hash.new(0)
rows.each do |p|
  sit = situate(p)
  eol = p["archived"] == 1 ? 1 : 0
  dtc = dead_deps[p["purl"]]
  upd.execute(sit, eol, dtc, dtc > 0 ? 1 : 0, sit ? "heuristic" : nil, now, p["purl"])
  counts[sit || "null"] += 1
end
upd.close

counts.sort_by { |_, v| -v }.each { |k, v| puts "  #{k.ljust(16)} #{v}" }
