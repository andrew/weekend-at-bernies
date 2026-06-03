#!/usr/bin/env ruby
# Re-parse the cached whois responses with a corrected priority order:
# expiry date first (most reliable signal), then registrar presence, then
# availability text. The previous parser triggered on trailing
# "ERROR: domain not found" lines that macOS whois appends after real
# registrar data, misclassifying active domains as available.

require "sqlite3"
require "time"
require "digest"

WORKDIR     = __dir__
DB_PATH     = File.join(WORKDIR, "bernies.db")
WHOIS_CACHE = File.join(WORKDIR, "cache", "emails", "whois")

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

  expt = nil
  if exp
    expt = (Time.parse(exp) rescue nil)
  end

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

  expires_at = expt ? expt.iso8601 : nil
  { status: status, expires_at: expires_at, registrar: registrar }
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

upd = db.prepare(<<~SQL)
  UPDATE email_domains SET whois_status=?, whois_expires_at=?, whois_registrar=?, checked_at=datetime('now')
  WHERE domain=?
SQL

rows = db.execute("SELECT domain FROM email_domains WHERE kind='custom'")
changed = unchanged = nofile = 0
rows.each do |r|
  d = r["domain"]
  file = File.join(WHOIS_CACHE, "#{Digest::SHA256.hexdigest(d)[0, 32]}.txt")
  unless File.exist?(file)
    nofile += 1
    next
  end
  parsed = reparse(File.read(file))
  upd.execute(parsed[:status], parsed[:expires_at], parsed[:registrar], d)
  changed += 1
end
upd.close

puts "reparsed #{changed} domains, #{nofile} had no cached whois"
puts
puts "new status distribution:"
db.execute("SELECT whois_status, COUNT(*) AS n FROM email_domains WHERE kind='custom' GROUP BY whois_status ORDER BY n DESC").each do |r|
  printf "  %-12s %d\n", r["whois_status"] || "(null)", r["n"]
end
