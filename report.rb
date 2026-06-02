#!/usr/bin/env ruby
# Summary stats and CSV exports for the talk.
#
# Writes:
#   out/buckets-by-ecosystem.csv   active/dormant/dead/unknown counts per ecosystem
#   out/dead.csv                   dead repos ranked by max dependent_repos
#   out/dormant.csv                dormant repos ranked by max dependent_repos
#   findings/<lang>.csv            per-ecosystem remediation data alongside writeups
#
# Usage: ruby report.rb

require "sqlite3"
require "csv"
require "json"
require "fileutils"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
OUTDIR  = File.join(WORKDIR, "out")
FileUtils.mkdir_p(OUTDIR)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

puts "== overall =="
db.execute("SELECT bucket, COUNT(*) AS n FROM repos GROUP BY bucket ORDER BY n DESC").each do |r|
  printf "  %-8s %6d\n", r["bucket"], r["n"]
end
puts

puts "== by ecosystem (distinct repos) =="
rows = db.execute <<~SQL
  SELECT p.ecosystem,
         COUNT(DISTINCT r.repository_url) AS repos,
         COUNT(DISTINCT CASE WHEN r.bucket='active'  THEN r.repository_url END) AS active,
         COUNT(DISTINCT CASE WHEN r.bucket='dormant' THEN r.repository_url END) AS dormant,
         COUNT(DISTINCT CASE WHEN r.bucket='dead'    THEN r.repository_url END) AS dead,
         COUNT(DISTINCT CASE WHEN r.bucket='unknown' THEN r.repository_url END) AS unknown
  FROM packages p JOIN repos r ON p.repository_url = r.repository_url
  GROUP BY p.ecosystem
  ORDER BY repos DESC
SQL
CSV.open(File.join(OUTDIR, "buckets-by-ecosystem.csv"), "w") do |csv|
  csv << %w[ecosystem repos active dormant dead unknown dead_pct]
  rows.each do |r|
    pct = r["repos"].zero? ? 0 : (100.0 * r["dead"] / r["repos"])
    csv << [r["ecosystem"], r["repos"], r["active"], r["dormant"], r["dead"], r["unknown"], pct.round(1)]
    printf "  %-12s repos=%-6d active=%-6d dormant=%-6d dead=%-6d (%.1f%%)\n",
           r["ecosystem"], r["repos"], r["active"], r["dormant"], r["dead"], pct
  end
end
puts

def export_bucket(db, bucket, path)
  rows = db.execute <<~SQL, [bucket]
    SELECT r.repository_url,
           GROUP_CONCAT(DISTINCT p.ecosystem) AS ecosystems,
           GROUP_CONCAT(DISTINCT p.name)      AS package_names,
           MAX(p.dependent_repos)             AS dependent_repos,
           MAX(p.dependent_packages)          AS dependent_packages,
           MAX(p.downloads)                   AS downloads,
           MAX(p.registry_maintainers_count)  AS registry_maintainers,
           r.stars, r.archived, r.language,
           r.days_since_release, r.days_since_commit, r.days_since_push,
           r.past_year_commits, r.past_year_committers,
           r.active_maintainers_count, r.past_year_prs_merged, r.past_year_issues_closed,
           r.advisories_count, r.unpatched_advisories_count, r.signals
    FROM repos r JOIN packages p ON p.repository_url = r.repository_url
    WHERE r.bucket = ?
    GROUP BY r.repository_url
    ORDER BY dependent_repos DESC NULLS LAST
  SQL
  CSV.open(path, "w") do |csv|
    csv << %w[repository_url ecosystems package_names dependent_repos dependent_packages downloads
              registry_maintainers stars archived language days_since_release days_since_commit
              days_since_push past_year_commits past_year_committers active_maintainers_count
              past_year_prs_merged past_year_issues_closed advisories_count
              unpatched_advisories_count signals]
    rows.each { |r| csv << r.values }
  end
  rows
end

bernies = db.execute <<~SQL
  SELECT r.repository_url, r.bucket,
         GROUP_CONCAT(DISTINCT p.ecosystem)       AS ecosystems,
         GROUP_CONCAT(DISTINCT p.name)            AS package_names,
         MAX(p.dependent_repos)                   AS dependent_repos,
         MAX(p.dependent_packages)                AS dependent_packages,
         MAX(p.downloads)                         AS downloads,
         r.stars, r.language,
         r.days_since_release, r.days_since_commit, r.days_since_push,
         r.past_year_commits, r.past_year_committers, r.dds,
         r.active_maintainers_count,
         MAX(p.registry_maintainers_count)        AS registry_maintainers,
         r.past_year_issues, r.past_year_prs,
         r.past_year_issues_closed, r.past_year_prs_merged,
         COALESCE(r.advisories_count, 0)          AS advisories,
         COALESCE(r.unpatched_advisories_count,0) AS unpatched_advisories,
         r.archived, r.signals
  FROM repos r JOIN packages p ON p.repository_url = r.repository_url
  WHERE r.bucket IN ('dead','dormant')
  GROUP BY r.repository_url
  ORDER BY dependent_repos DESC NULLS LAST
SQL
CSV.open(File.join(OUTDIR, "bernies.csv"), "w") do |csv|
  csv << %w[repository_url bucket ecosystems package_names dependent_repos dependent_packages
            downloads stars language days_since_release days_since_commit days_since_push
            past_year_commits past_year_committers dds active_maintainers_count
            registry_maintainers past_year_issues past_year_prs past_year_issues_closed
            past_year_prs_merged advisories unpatched_advisories archived signals]
  bernies.each { |r| csv << r.values }
end

unpatched = db.execute <<~SQL
  SELECT a.repository_url, r.bucket, a.ecosystem, a.package_name, a.identifier,
         a.severity, a.cvss_score, a.published_at, a.vulnerable_range,
         p.dependent_repos, p.downloads, r.days_since_release, r.days_since_commit
  FROM advisories a
  JOIN packages p ON a.purl = p.purl
  LEFT JOIN repos r ON a.repository_url = r.repository_url
  WHERE a.patched = 0 AND a.withdrawn_at IS NULL
  ORDER BY p.dependent_repos DESC NULLS LAST
SQL
CSV.open(File.join(OUTDIR, "unpatched.csv"), "w") do |csv|
  csv << %w[repository_url bucket ecosystem package_name identifier severity cvss_score
            published_at vulnerable_range dependent_repos downloads days_since_release
            days_since_commit]
  unpatched.each { |r| csv << r.values }
end

remediation = db.execute <<~SQL
  SELECT p.purl, p.name, p.ecosystem, r.bucket,
         p.situation, p.eol_direct, p.dead_transitive_count,
         p.remediation, p.alternative_purl, p.remediation_notes, p.remediation_source,
         p.llm_confidence, p.dependent_repos, p.top1_dependent,
         r.code_loc, r.complexity, r.has_native,
         COALESCE(r.unpatched_advisories_count, 0) AS unpatched_advisories,
         p.repository_url
  FROM packages p LEFT JOIN repos r ON r.repository_url = p.repository_url
  WHERE r.bucket IN ('dead','dormant','unknown')
  ORDER BY p.dependent_repos DESC NULLS LAST
SQL
REMEDIATION_COLS = %w[purl name ecosystem bucket situation eol_direct dead_transitive_count
                      remediation alternative_purl remediation_notes remediation_source
                      llm_confidence dependent_repos top1_dependent code_loc complexity
                      has_native unpatched_advisories repository_url]
CSV.open(File.join(OUTDIR, "remediation.csv"), "w") do |csv|
  csv << REMEDIATION_COLS
  remediation.each { |r| csv << r.values }
end
File.write(File.join(OUTDIR, "remediation.json"), JSON.pretty_generate(remediation))

FINDINGS_DIR = File.join(WORKDIR, "findings")
ECO_TO_LANG  = { "rubygems" => "ruby", "cargo" => "rust", "packagist" => "php", "maven" => "java" }
FileUtils.mkdir_p(FINDINGS_DIR)
remediation.group_by { |r| r["ecosystem"] }.each do |eco, rows|
  name = ECO_TO_LANG.fetch(eco, eco)
  CSV.open(File.join(FINDINGS_DIR, "#{name}.csv"), "w") do |csv|
    csv << REMEDIATION_COLS
    rows.each { |r| csv << r.values }
  end
end

dead    = export_bucket(db, "dead",    File.join(OUTDIR, "dead.csv"))
dormant = export_bucket(db, "dormant", File.join(OUTDIR, "dormant.csv"))

puts "== bernies (dead+dormant by dependent_repos, top 20) =="
bernies.first(20).each do |r|
  adv = r["advisories"].to_i
  flag = adv > 0 ? " adv=#{adv}#{"!" if r["unpatched_advisories"].to_i > 0}" : ""
  printf "  %-7s %-45s deps=%-9s rel=%-6s maint=%-2s%s\n",
         r["bucket"], r["repository_url"].sub("https://", ""),
         r["dependent_repos"], r["days_since_release"],
         r["active_maintainers_count"] || r["registry_maintainers"], flag
end
puts
tagged = remediation.count { |r| r["remediation"] }
puts "wrote #{remediation.size} non-active (#{tagged} with remediation) -> out/remediation.{csv,json}"
puts "wrote #{bernies.size} dead+dormant -> out/bernies.csv"
puts "wrote #{dead.size} dead -> out/dead.csv, #{dormant.size} dormant -> out/dormant.csv"
puts "wrote #{unpatched.size} unpatched advisories -> out/unpatched.csv"
puts "wrote out/buckets-by-ecosystem.csv"
