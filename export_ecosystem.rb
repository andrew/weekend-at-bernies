#!/usr/bin/env ruby
# Per-package dead+dormant export for a single ecosystem.
#
# Usage: ruby export_ecosystem.rb cargo
# Writes: out/<ecosystem>-bernies.csv

require "sqlite3"
require "csv"
require "fileutils"

ECOSYSTEM = ARGV[0] or abort "usage: ruby export_ecosystem.rb <ecosystem>"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
OUTDIR  = File.join(WORKDIR, "out")
FileUtils.mkdir_p(OUTDIR)

REGISTRY_URL = {
    "cargo"     => ->(n) { "https://crates.io/crates/#{n}" },
    "npm"       => ->(n) { "https://www.npmjs.com/package/#{n}" },
    "rubygems"  => ->(n) { "https://rubygems.org/gems/#{n}" },
    "pypi"      => ->(n) { "https://pypi.org/project/#{n}" },
    "packagist" => ->(n) { "https://packagist.org/packages/#{n}" },
    "hex"       => ->(n) { "https://hex.pm/packages/#{n}" },
    "go"        => ->(n) { "https://pkg.go.dev/#{n}" },
}

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

rows = db.execute <<~SQL, [ECOSYSTEM]
    SELECT p.name,
           r.bucket,
           p.repository_url,
           p.dependent_repos,
           p.dependent_packages,
           p.downloads,
           p.latest_release,
           p.latest_release_at,
           p.registry_maintainers_count        AS crate_owners,
           r.archived,
           r.days_since_commit,
           r.past_year_commits,
           r.past_year_committers,
           r.active_maintainers_count,
           r.past_year_issues,
           r.past_year_prs,
           r.past_year_issues_closed,
           r.past_year_prs_merged,
           COALESCE(r.advisories_count, 0)          AS advisories,
           COALESCE(r.unpatched_advisories_count,0) AS unpatched_advisories,
           r.signals
    FROM packages p
    JOIN repos r ON p.repository_url = r.repository_url
    WHERE p.ecosystem = ?
      AND r.bucket IN ('dead', 'dormant')
    ORDER BY r.bucket, p.dependent_repos DESC NULLS LAST
SQL

url_for = REGISTRY_URL[ECOSYSTEM]
path = File.join(OUTDIR, "#{ECOSYSTEM}-bernies.csv")
CSV.open(path, "w") do |csv|
    csv << %w[name bucket registry_url repository_url dependent_repos dependent_packages
              downloads latest_release latest_release_at crate_owners archived
              days_since_commit past_year_commits past_year_committers
              active_maintainers_count past_year_issues past_year_prs
              past_year_issues_closed past_year_prs_merged advisories
              unpatched_advisories signals]
    rows.each do |r|
        csv << [r["name"], r["bucket"], url_for&.call(r["name"]), *r.values.drop(2)]
    end
end

dead    = rows.count { |r| r["bucket"] == "dead" }
dormant = rows.count { |r| r["bucket"] == "dormant" }
puts "wrote #{rows.size} #{ECOSYSTEM} packages (#{dead} dead, #{dormant} dormant) -> #{path}"
