#!/usr/bin/env ruby
# Usage: ruby mydataset.rb FILE

require "csv"
require "sqlite3"
require "uri"
require_relative "http"
require_relative "database"
require_relative "package_writer"

abort "Usage: ruby mydataset.rb FILE" unless ARGV.size == 1

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
Bernies.create_core_tables(db)
writer = Bernies::PackageWriter.new(db)
imported = unavailable = 0

begin
  names.uniq.each do |name|
    path = "/api/v1/registries/rubygems.org/packages/#{URI.encode_www_form_component(name)}"
    package = cached_get(connection, path, {}, cache)
    unless package.is_a?(Hash) && package["purl"] && package["name"] && package["ecosystem"]
      warn "#{name}: package not found or unavailable"
      unavailable += 1
      next
    end

    db.transaction { writer.write(package, "rubygems.org") }
    imported += 1
    puts "imported #{name}"
  end
ensure
  writer.close
  db.close
end

puts "imported #{imported}, unavailable #{unavailable} into #{db_path}"
exit 1 if unavailable.positive?
