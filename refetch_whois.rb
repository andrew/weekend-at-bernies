#!/usr/bin/env ruby
# Re-fetch whois for domains where the macOS system whois failed to return
# parseable data (status unknown / error / no_whois_tool). Uses the homebrew
# whois (rfc1036) which chases registrar referrals properly and handles
# ccTLDs that the system tool stops short on.
#
# Reuses the existing cache for everything else. Throttles at 5s/query.
#
# Usage: ruby refetch_whois.rb [LIMIT]

require "sqlite3"
require "digest"
require "open3"
require "time"
require "fileutils"

WORKDIR     = __dir__
DB_PATH     = File.join(WORKDIR, "bernies.db")
WHOIS_CACHE = File.join(WORKDIR, "cache", "emails", "whois")
LIMIT       = ARGV[0]&.to_i
DELAY       = 5

WHOIS_BIN = ["/opt/homebrew/opt/whois/bin/whois", "/usr/local/opt/whois/bin/whois"].find { |p| File.executable?(p) }
abort "homebrew whois not found (brew install whois)" unless WHOIS_BIN
puts "using #{WHOIS_BIN}"

def reparse(raw)
  return { status: "error", expires_at: nil, registrar: nil } if raw.start_with?("ERROR\n")

  exp = nil
  raw.each_line do |line|
    if line =~ /(?:Registry Expiry Date|Registrar Registration Expiration Date|Expiration Date|Expiry Date|Expires On|paid-till)\s*:\s*(.+)/i
      exp = $1.strip
      break
    end
  end

  registrar = nil
  raw.each_line do |line|
    if line =~ /^\s*Registrar\s*:\s*(.+?)\s*$/i
      registrar = $1.strip
      break unless registrar.empty?
    end
  end

  expt = exp ? (Time.parse(exp) rescue nil) : nil

  status =
    if expt
      expt < Time.now ? "expired" : "active"
    elsif registrar
      "active"
    elsif raw =~ /redacted for privacy|REDACTED FOR PRIVACY/i
      "private"
    elsif raw =~ /^\s*(?:No match for|NOT FOUND|No Data Found|Domain not found|is free|Status:\s*free|Status:\s*AVAILABLE|This domain is available)/i
      "available"
    else
      "unknown"
    end

  { status: status, expires_at: expt&.iso8601, registrar: registrar }
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

todo = db.execute(<<~SQL).map { |r| r["domain"] }
  SELECT domain FROM email_domains
  WHERE kind='custom'
    AND whois_status IN ('unknown','error','no_whois_tool')
  ORDER BY domain
SQL
todo = todo.first(LIMIT) if LIMIT
puts "#{todo.size} domains to refetch"

upd = db.prepare(<<~SQL)
  UPDATE email_domains SET whois_status=?, whois_expires_at=?, whois_registrar=?, checked_at=datetime('now')
  WHERE domain=?
SQL

changed = Hash.new(0)
todo.each_with_index do |d, i|
  cache_file = File.join(WHOIS_CACHE, "#{Digest::SHA256.hexdigest(d)[0, 32]}.txt")
  sleep DELAY
  out, _err, status = Open3.capture3({ "LANG" => "C" }, WHOIS_BIN, d)
  if status.success? && !out.strip.empty?
    File.write(cache_file, out)
    parsed = reparse(out)
  else
    File.write(cache_file, "ERROR\n")
    parsed = { status: "error", expires_at: nil, registrar: nil }
  end
  upd.execute(parsed[:status], parsed[:expires_at], parsed[:registrar], d)
  changed[parsed[:status]] += 1
  print "\r[#{i + 1}/#{todo.size}] #{changed.map { |k, v| "#{k}=#{v}" }.join(' ')}"
end
upd.close
puts
puts
puts "final distribution:"
db.execute("SELECT whois_status, COUNT(*) AS n FROM email_domains WHERE kind='custom' GROUP BY whois_status ORDER BY n DESC").each do |r|
  printf "  %-12s %d\n", r["whois_status"] || "(null)", r["n"]
end
