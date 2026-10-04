#!/usr/bin/env ruby
# Usage: ruby mydataset.rb [--refresh] [--failures FILE] INPUT

require "csv"
require "sqlite3"
require "uri"
require "optparse"
require_relative "http"
require_relative "database"
require_relative "package_writer"
require_relative "lookup_failures"

options = {}
OptionParser.new do |parser|
  parser.on("--refresh") { options[:refresh] = true }
  parser.on("--failures FILE") { |path| options[:failures] = path }
end.parse!
refresh = !!options[:refresh]
abort "Usage: ruby mydataset.rb [--refresh] FILE" unless ARGV.size == 1

names = []
errors = []
begin
  CSV.foreach(ARGV.first, strip: true, skip_blanks: true).with_index(1) do |row, number|
    type, name = row
    if !(2..3).cover?(row.size) || type != "pkg:gem" || !name.to_s.match?(/\A[A-Za-z0-9_.-]+\z/)
      errors << "row #{number}: expected pkg:gem,name[,comment]"
    else
      names << name
    end
  end
rescue CSV::MalformedCSVError, SystemCallError => e
  abort e.message
end
abort errors.join("\n") unless errors.empty?
abort "No packages in #{ARGV.first}" if names.empty?

cache = File.join(__dir__, "cache", "mydataset")
FileUtils.mkdir_p(cache)
connection = conn("https://packages.ecosyste.ms")
db_path = Bernies.database_path
db = SQLite3::Database.new(db_path)
db.busy_timeout = 5000
db.results_as_hash = true
Bernies.create_core_tables(db)
writer = Bernies::PackageWriter.new(db)
failures = Bernies::LookupFailures.new(db, "mydataset")
imported = unavailable = 0

begin
  names.uniq.each do |name|
    path = "/api/v1/registries/rubygems.org/packages/#{URI.encode_www_form_component(name)}"
    result = cached_response(connection, path, {}, cache, refresh: refresh || failures.recorded?("package", "pkg:gem/#{name}"))
    package = result.data
    unless package.is_a?(Hash) && package["purl"] && package["name"] && package["ecosystem"]
      warn "#{name}: package not found or unavailable"
      puts ; puts "miss: #{failures.record('package', "pkg:gem/#{name}", result)}"
      unavailable += 1
      next
    end

    db.transaction { writer.write(package, "rubygems.org") }
    failures.clear("package", "pkg:gem/#{name}")
    imported += 1
    puts "imported #{name}"
  end
ensure
  Bernies::LookupFailures.export(db, options[:failures], collector: "mydataset") if options[:failures]
  writer.close
  db.close
end

puts "imported #{imported}, unavailable #{unavailable} into #{db_path}"
exit 1 if unavailable.positive?
