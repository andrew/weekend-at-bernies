#!/usr/bin/env ruby
# Pull critical packages from packages.ecosyste.ms into bernies.db.
# Creates the packages table (one row per purl) and seeds the repos table
# (one row per unique repository_url) from embedded repo_metadata.
#
# Responses cached under cache/packages so re-runs are cheap.
#
# Usage: ruby fetch.rb [registry ...]

require "json"
require "sqlite3"
require "digest"
require "fileutils"
require "time"
require_relative "http"
require_relative "database"

WORKDIR = __dir__
DB_PATH = Bernies.database_path
CACHE   = File.join(WORKDIR, "cache", "packages")
CONN    = conn("https://packages.ecosyste.ms")

REGISTRIES = %w[
  npmjs.org
  pypi.org
  rubygems.org
  crates.io
  proxy.golang.org
  repo1.maven.org
  nuget.org
  packagist.org
  pub.dev
  hex.pm
  cocoapods.org
  metacpan.org
  hackage.haskell.org
  juliahub.com
  conda-forge.org
  swiftpackageindex.com
]

FileUtils.mkdir_p(CACHE)

def get(url)
  key = Digest::SHA256.hexdigest(url)[0, 32]
  path = File.join(CACHE, "#{key}.json")
  if File.exist?(path)
    data = JSON.parse(File.read(path))
    return [data["packages"], data["next"]]
  end

  res = CONN.get(url)
  raise "#{res.status} for #{url}" unless res.success?

  packages = JSON.parse(res.body)
  link = res.headers["link"] || ""
  next_url = link[/<([^>]+)>;\s*rel="next"/, 1]

  File.write(path, JSON.generate(packages: packages, next: next_url))
  sleep 0.2
  [packages, next_url]
end

def norm_repo(url)
  return nil if url.nil? || url.strip.empty?
  u = url.strip.sub(%r{^http://}, "https://")
  return nil unless u.start_with?("https://")
  u.sub(%r{://www\.}, "://").chomp("/").chomp(".git").downcase
end

def owner_from(url)
  return [nil, nil] if url.nil?
  parts = url.sub(%r{^https?://}, "").split("/")
  [parts[0], parts[1]]
end

db = SQLite3::Database.new(DB_PATH)
Bernies.create_core_tables(db)

PKG_COLS = %w[
  purl registry ecosystem name repository_url
  dependent_repos dependent_packages downloads downloads_period
  latest_release latest_release_at first_release_at versions_count
  status rankings_avg registry_maintainers_count registry_maintainers fetched_at
]
ins_pkg = db.prepare <<~SQL
  INSERT INTO packages (#{PKG_COLS.join(",")}) VALUES (#{(["?"] * PKG_COLS.size).join(",")})
  ON CONFLICT(purl) DO UPDATE SET
    #{(PKG_COLS - %w[purl registry ecosystem name]).map { |c| "#{c}=excluded.#{c}" }.join(",")}
SQL

REPO_COLS = %w[
  repository_url host owner stars forks open_issues archived fork repo_status
  has_issues prs_enabled language license default_branch repo_created_at pushed_at
]
ins_repo = db.prepare <<~SQL
  INSERT INTO repos (#{REPO_COLS.join(",")}) VALUES (#{(["?"] * REPO_COLS.size).join(",")})
  ON CONFLICT(repository_url) DO UPDATE SET
    #{(REPO_COLS - %w[repository_url host owner]).map { |c| "#{c}=COALESCE(excluded.#{c}, #{c})" }.join(",")}
SQL

now = Time.now.utc.iso8601
targets = ARGV.empty? ? REGISTRIES : ARGV
b = ->(v) { v.nil? ? nil : (v ? 1 : 0) }

targets.each do |registry|
  url = "https://packages.ecosyste.ms/api/v1/registries/#{registry}/packages?critical=true&per_page=100&page=1"
  page = 0
  total = 0
  db.transaction
  while url
    page += 1
    packages, url = get(url)
    packages.each do |p|
      purl = p["purl"] or next
      repo = norm_repo(p["repository_url"])
      maint = (p["maintainers"] || []).map { |m| m["uuid"] || m["login"] }.compact
      ins_pkg.execute(
        purl, registry, p["ecosystem"], p["name"], repo,
        p["dependent_repos_count"], p["dependent_packages_count"],
        p["downloads"], p["downloads_period"],
        p["latest_release_number"], p["latest_release_published_at"],
        p["first_release_published_at"], p["versions_count"],
        p["status"], (p["rankings"] || {})["average"],
        maint.size, maint.join(","),
        now
      )
      if repo
        host, owner = owner_from(repo)
        m = p["repo_metadata"] || {}
        ins_repo.execute(
          repo, host, owner,
          m["stargazers_count"], m["forks_count"], m["open_issues_count"],
          b[m["archived"]], b[m["fork"]], m["status"],
          b[m["has_issues"]], b[m["pull_requests_enabled"]],
          m["language"], m["license"], m["default_branch"],
          m["created_at"], m["pushed_at"]
        )
      end
      total += 1
    end
    print "\r#{registry.ljust(24)} page #{page}  (#{total} pkgs)"
  end
  db.commit
  puts
rescue => e
  db.rollback rescue nil
  warn "\n#{registry}: #{e.class}: #{e.message}"
end

ins_pkg.close
ins_repo.close

n = db.get_first_value("SELECT COUNT(*) FROM packages")
r = db.get_first_value("SELECT COUNT(*) FROM repos")
puts
puts "#{n} packages, #{r} repos in #{DB_PATH}"
