#!/usr/bin/env ruby
# Pull the top N npm packages by monthly downloads from packages.ecosyste.ms.
# Writes out/top_npm_by_downloads.csv. Separate from bernies.db on purpose:
# this set is not filtered by critical=true, so we can compare new vs old
# without the critical-floor truncation.
#
# Usage: ruby top_npm.rb [N]   (default 2000)

require "csv"
require "json"
require "digest"
require "fileutils"
require_relative "http"

WORKDIR = __dir__
CACHE   = File.join(WORKDIR, "cache", "top_npm")
OUT     = File.join(WORKDIR, "out", "top_npm_by_downloads.csv")
CONN    = conn("https://packages.ecosyste.ms")
TARGET  = (ARGV.first || 2000).to_i

FileUtils.mkdir_p(CACHE)
FileUtils.mkdir_p(File.dirname(OUT))

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

url  = "https://packages.ecosyste.ms/api/v1/registries/npmjs.org/packages?sort=downloads&order=desc&per_page=100&page=1"
rows = []
page = 0

while url && rows.size < TARGET
  page += 1
  packages, url = get(url)
  packages.each do |p|
    rows << [
      p["name"],
      p["downloads"],
      p["downloads_period"],
      p["first_release_published_at"],
      p["latest_release_published_at"],
      p["repository_url"],
      p["dependent_packages_count"]
    ]
    break if rows.size >= TARGET
  end
  print "\rpage #{page}  (#{rows.size} pkgs)"
end
puts

CSV.open(OUT, "w") do |csv|
  csv << %w[name downloads downloads_period first_release_at latest_release_at repository_url dependent_packages]
  rows.each { |r| csv << r }
end

puts "wrote #{rows.size} rows to #{OUT}"
