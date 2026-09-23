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
require_relative "package_writer"

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

db = SQLite3::Database.new(DB_PATH)
Bernies.create_core_tables(db)
writer = Bernies::PackageWriter.new(db)
targets = ARGV.empty? ? REGISTRIES : ARGV

targets.each do |registry|
  url = "https://packages.ecosyste.ms/api/v1/registries/#{registry}/packages?critical=true&per_page=100&page=1"
  page = 0
  total = 0
  db.transaction
  while url
    page += 1
    packages, url = get(url)
    packages.each do |p|
      total += 1 if writer.write(p, registry)
    end
    print "\r#{registry.ljust(24)} page #{page}  (#{total} pkgs)"
  end
  db.commit
  puts
rescue => e
  db.rollback rescue nil
  warn "\n#{registry}: #{e.class}: #{e.message}"
end

writer.close

n = db.get_first_value("SELECT COUNT(*) FROM packages")
r = db.get_first_value("SELECT COUNT(*) FROM repos")
puts
puts "#{n} packages, #{r} repos in #{DB_PATH}"
