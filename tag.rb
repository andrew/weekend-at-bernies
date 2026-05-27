#!/usr/bin/env ruby
# Manual review of situation/remediation via CSV round-trip.
#
#   ruby tag.rb                       export untagged non-active to out/tag.csv
#   ruby tag.rb --ecosystem rubygems  filter export to one ecosystem
#   ruby tag.rb --import out/tag.csv  write edits back, remediation_source=human
#
# On import, only rows where situation/remediation/alternative_purl/notes
# differ from the db are touched, so partial edits are fine. Blank cells
# mean "leave as is".

require "csv"
require "sqlite3"
require "fileutils"
require "time"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
OUT     = File.join(WORKDIR, "out")
ECO     = (i = ARGV.index("--ecosystem")) && ARGV[i + 1]
IMPORT  = (i = ARGV.index("--import")) && ARGV[i + 1]

SITUATIONS   = %w[few-large broad inlineable alternative kitchen-sink no-alternative]
REMEDIATIONS = %w[adopt vendor switch switch-piecemeal accept]

FileUtils.mkdir_p(OUT)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

if IMPORT
  upd = db.prepare <<~SQL
    UPDATE packages SET situation=?, eol_direct=?, remediation=?,
      alternative_purl=?, remediation_notes=?, remediation_source='human',
      tagged_at=? WHERE purl=?
  SQL
  now = Time.now.utc.iso8601
  n = changed = 0
  CSV.foreach(IMPORT, headers: true) do |row|
    n += 1
    purl = row["purl"] or next
    sit  = row["situation"]&.strip
    rem  = row["remediation"]&.strip
    next if sit.to_s.empty? && rem.to_s.empty?
    abort "row #{n}: bad situation '#{sit}'"   if !sit.to_s.empty? && !SITUATIONS.include?(sit)
    abort "row #{n}: bad remediation '#{rem}'" if !rem.to_s.empty? && !REMEDIATIONS.include?(rem)

    cur = db.get_first_row("SELECT situation, eol_direct, remediation, alternative_purl, remediation_notes FROM packages WHERE purl=?", purl)
    next unless cur
    eol = row["eol_direct"]&.strip
    eol = eol.to_s.empty? ? cur["eol_direct"] : (%w[1 true yes y].include?(eol.downcase) ? 1 : 0)
    alt = row["alternative_purl"]&.strip
    alt = nil if alt.to_s.empty?
    notes = row["remediation_notes"]&.strip
    notes = cur["remediation_notes"] if notes.to_s.empty?

    new_vals = [sit.to_s.empty? ? cur["situation"] : sit, eol,
                rem.to_s.empty? ? cur["remediation"] : rem, alt, notes]
    next if new_vals == cur.values_at("situation", "eol_direct", "remediation", "alternative_purl", "remediation_notes")

    upd.execute(*new_vals, now, purl)
    changed += 1
  end
  upd.close
  puts "imported #{n} rows, updated #{changed}"
  exit
end

eco_filter = ECO ? "AND p.ecosystem = '#{ECO}'" : ""
rows = db.execute(<<~SQL)
  SELECT p.purl, p.name, p.ecosystem, r.bucket,
         p.dependent_repos, p.dependent_packages, p.top1_dependent,
         r.code_loc, r.complexity, r.has_native, r.unpatched_advisories_count,
         p.dead_transitive_count, p.situation, p.eol_direct, p.remediation,
         p.alternative_purl, p.remediation_notes, p.remediation_source,
         p.llm_confidence, p.repository_url
  FROM packages p LEFT JOIN repos r ON r.repository_url = p.repository_url
  WHERE r.bucket IN ('dead','dormant','unknown') #{eco_filter}
  ORDER BY p.dependent_repos DESC
SQL

path = File.join(OUT, "tag.csv")
CSV.open(path, "w") do |csv|
  csv << %w[
    purl name ecosystem bucket dependent_repos dependent_packages top1_dependent
    code_loc complexity has_native unpatched_advisories dead_transitive_count
    situation eol_direct remediation alternative_purl remediation_notes
    remediation_source llm_confidence repository_url
  ]
  rows.each do |r|
    csv << [
      r["purl"], r["name"], r["ecosystem"], r["bucket"],
      r["dependent_repos"], r["dependent_packages"], r["top1_dependent"],
      r["code_loc"], r["complexity"], r["has_native"], r["unpatched_advisories_count"],
      r["dead_transitive_count"], r["situation"], r["eol_direct"], r["remediation"],
      r["alternative_purl"], r["remediation_notes"], r["remediation_source"],
      r["llm_confidence"]&.round(2), r["repository_url"]
    ]
  end
end
puts "#{rows.size} rows exported to #{path}"
puts "edit situation/remediation/alternative_purl/remediation_notes columns, then:"
puts "  ruby tag.rb --import #{path}"
