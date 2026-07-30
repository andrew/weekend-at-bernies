#!/usr/bin/env ruby
# Export the ranked science cohort with Bernies activity and ownership signals.
#
# Usage: ruby report_science.rb
#        BERNIES_DB=science-bernies.db ruby report_science.rb

require "csv"
require "fileutils"
require "sqlite3"
require_relative "database"

WORKDIR = __dir__
DB_PATH = Bernies.database_path("science-bernies.db")
OUTDIR = File.join(WORKDIR, "out")

FileUtils.mkdir_p(OUTDIR)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

columns = %w[
  rank name repository_url bucket science_score project_score total_citations
  category sub_category language owner_login owner_name owner_kind owner_company
  owner_website ecosystems package_names monthly_downloads dependent_repos
  dependent_packages registry_maintainers stars archived days_since_release
  days_since_commit days_since_push total_committers past_year_commits
  past_year_committers dds past_year_dds issue_maintainers_count
  active_maintainers_count active_maintainers past_year_issues past_year_prs
  past_year_issues_closed past_year_prs_merged advisories
  unpatched_advisories signals science_html_url
]

rows = db.execute <<~SQL
  SELECT sp.rank, sp.name, sp.repository_url, r.bucket,
         sp.science_score, sp.project_score, sp.total_citations,
         sp.category, sp.sub_category, COALESCE(r.language, sp.language) AS language,
         sp.owner_login, sp.owner_name, sp.owner_kind, sp.owner_company,
         sp.owner_website,
         GROUP_CONCAT(DISTINCT p.ecosystem) AS ecosystems,
         GROUP_CONCAT(DISTINCT p.name) AS package_names,
         sp.monthly_downloads,
         MAX(p.dependent_repos) AS dependent_repos,
         MAX(p.dependent_packages) AS dependent_packages,
         MAX(p.registry_maintainers_count) AS registry_maintainers,
         r.stars, r.archived, r.days_since_release, r.days_since_commit,
         r.days_since_push, r.total_committers, r.past_year_commits,
         r.past_year_committers, r.dds, r.past_year_dds,
         r.issue_maintainers_count, r.active_maintainers_count,
         r.active_maintainers, r.past_year_issues, r.past_year_prs,
         r.past_year_issues_closed, r.past_year_prs_merged,
         COALESCE(r.advisories_count, 0) AS advisories,
         COALESCE(r.unpatched_advisories_count, 0) AS unpatched_advisories,
         r.signals, sp.science_html_url
  FROM science_projects sp
  JOIN repos r ON r.repository_url = sp.repository_url
  LEFT JOIN packages p ON p.repository_url = sp.repository_url
  GROUP BY sp.science_id
  ORDER BY sp.rank
SQL

def write_csv(path, columns, rows)
  CSV.open(path, "w") do |csv|
    csv << columns
    rows.each { |row| csv << row.values_at(*columns) }
  end
end

write_csv(File.join(OUTDIR, "science-projects.csv"), columns, rows)

bernies = rows.select { |row| %w[dead dormant].include?(row["bucket"]) }
write_csv(File.join(OUTDIR, "science-bernies.csv"), columns, bernies)

bucket_rows = rows
  .group_by { |row| row["bucket"] || "unclassified" }
  .sort_by { |bucket, grouped| [-grouped.size, bucket] }

CSV.open(File.join(OUTDIR, "science-buckets.csv"), "w") do |csv|
  csv << %w[bucket projects share]
  bucket_rows.each do |bucket, grouped|
    share = rows.empty? ? 0 : (100.0 * grouped.size / rows.size).round(1)
    csv << [bucket, grouped.size, share]
    printf "  %-12s %6d  (%4.1f%%)\n", bucket, grouped.size, share
  end
end

puts
puts "wrote #{rows.size} projects to out/science-projects.csv"
puts "wrote #{bernies.size} dead or dormant projects to out/science-bernies.csv"
puts "wrote out/science-buckets.csv"
