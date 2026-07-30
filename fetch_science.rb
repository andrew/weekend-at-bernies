#!/usr/bin/env ruby
# Pull the top-ranked scientific projects from science.ecosyste.ms into a
# separate database that can be enriched by the normal Bernies pipeline.
#
# Usage: ruby fetch_science.rb [N]   (default 2000)

require "fileutils"
require_relative "http"
require_relative "science_collector"

WORKDIR = __dir__
DB_PATH = Bernies.database_path("science-bernies.db")
CACHE = File.join(WORKDIR, "cache", "science")
TARGET = (ARGV.first || 2000).to_i
CONNECTION = conn("https://science.ecosyste.ms")

FileUtils.mkdir_p(CACHE)

client = Bernies::ScienceClient.new(CONNECTION, CACHE)
collector = Bernies::ScienceCollector.new(
  db_path: DB_PATH,
  client: client
)

count = collector.collect(TARGET)
puts "wrote #{count} ranked science projects to #{DB_PATH}"
