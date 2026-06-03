#!/usr/bin/env ruby
# Re-classify domains the original whois-based parser couldn't resolve.
# Tries RDAP first (structured JSON, served by ICANN-registered RDAP
# servers via rdap.org's bootstrap); falls back to the homebrew whois
# (rfc1036) for TLDs without working RDAP coverage.
#
# RDAP is the standardised replacement for whois (RFC 9082-9084).
# Coverage: .com / .net / .org / .info / most gTLDs have it; .io / .sh /
# .ai / many ccTLDs do not.
#
# Cached under cache/emails/rdap/ and cache/emails/whois/. Re-runs hit
# cache only.
#
# Usage: ruby refetch_domain_status.rb [LIMIT]

require "sqlite3"
require "json"
require "time"
require "digest"
require "open3"
require "fileutils"
require_relative "http"

WORKDIR     = __dir__
DB_PATH     = File.join(WORKDIR, "bernies.db")
RDAP_CACHE  = File.join(WORKDIR, "cache", "emails", "rdap")
WHOIS_CACHE = File.join(WORKDIR, "cache", "emails", "whois")
LIMIT       = ARGV[0]&.to_i
WHOIS_DELAY = 5
RDAP_DELAY  = 0.5

WHOIS_BIN = ["/opt/homebrew/opt/whois/bin/whois", "/usr/local/opt/whois/bin/whois"].find { |p| File.executable?(p) }

FileUtils.mkdir_p(RDAP_CACHE)
FileUtils.mkdir_p(WHOIS_CACHE)

RDAP_CONN = Faraday.new(url: "https://rdap.org", headers: { "User-Agent" => UA, "Accept" => "application/rdap+json" }) do |f|
  f.request :retry,
    max: 3, interval: 1, backoff_factor: 2,
    retry_statuses: [429, 500, 502, 503, 504],
    methods: [:get],
    exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, Faraday::TimeoutError]
  f.response :follow_redirects, limit: 5
  f.options.timeout = 10
  f.options.open_timeout = 5
  f.adapter Faraday.default_adapter
end

# RDAP returns:
#   200 + body  -> domain is registered; parse events for expiry
#   404         -> domain is not registered (available)
#   other       -> fall back to whois
def fetch_rdap(domain)
  cache_file = File.join(RDAP_CACHE, "#{Digest::SHA256.hexdigest(domain)[0, 32]}.json")
  if File.exist?(cache_file)
    body = File.read(cache_file)
    return body == "404" ? :not_found : (body == "ERROR" ? nil : JSON.parse(body))
  end
  sleep RDAP_DELAY
  res = RDAP_CONN.get("/domain/#{domain}")
  if res.status == 404
    File.write(cache_file, "404")
    :not_found
  elsif res.success? && !res.body.strip.empty?
    File.write(cache_file, res.body)
    JSON.parse(res.body) rescue (File.write(cache_file, "ERROR"); nil)
  else
    File.write(cache_file, "ERROR")
    nil
  end
rescue Faraday::Error, JSON::ParserError
  nil
end

def parse_rdap(data)
  # IMPORTANT: 404 from rdap.org is ambiguous — it can mean the domain is
  # not registered OR the TLD has no RDAP server in the bootstrap (.de, .li,
  # .edu, several ccTLDs). Returning :not_found here would tag every domain
  # under an RDAP-less TLD as "available", which is wrong. Instead, return
  # nil so the caller falls through to whois, which can disambiguate.
  return nil if data == :not_found || data.nil?
  events = data["events"] || []
  expiry = events.find { |e| e["eventAction"] == "expiration" }
  registrar = (data["entities"] || []).find { |e| (e["roles"] || []).include?("registrar") }&.dig("vcardArray", 1)&.find { |v| v.is_a?(Array) && v[0] == "fn" }&.dig(3)
  expt = expiry && (Time.parse(expiry["eventDate"]) rescue nil)
  status = if expt
    expt < Time.now ? "expired" : "active"
  elsif (data["status"] || []).any?
    "active"
  else
    "unknown"
  end
  { status: status, expires_at: expt&.iso8601, registrar: registrar, source: "rdap" }
end

# Domains we should never query — subdomains under known orgs, machine
# hostnames, accidental garbage in git committer configs. These are not
# registrable as standalone domains.
NON_REGISTRABLE = [
  /\.local$/i,              # mDNS / hostname
  /\.lan$/i,                # local LAN
  /\.internal$/i,           # Cloud-internal
  /\.edu$/i,                # ICANN-special; subdomains common in commit history (alum.mit.edu, etc.)
  /\.gov$/i,                # US gov, never registerable openly
  /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, # UUIDs
  /\.(arpa|onion|test|example|invalid|localhost)$/i,
  /\.[a-z]+\.[a-z]+\.[a-z]+\.[a-z]+/i,  # 4+ part hostnames (almost always subdomains)
]

def non_registrable?(domain)
  NON_REGISTRABLE.any? { |rx| domain =~ rx }
end

# whois fallback (homebrew binary, proper referral chasing)
def fetch_whois(domain)
  return nil unless WHOIS_BIN
  cache_file = File.join(WHOIS_CACHE, "#{Digest::SHA256.hexdigest(domain)[0, 32]}.txt")
  # Reuse only if it's NOT the macOS stub (look for actual registrar data)
  if File.exist?(cache_file)
    cached = File.read(cache_file)
    return cached if cached =~ /Registrar:|Registry Expiry|Expiration|No match for|NOT FOUND|Domain not found/i && !cached.start_with?("ERROR")
  end
  sleep WHOIS_DELAY
  out, _err, status = Open3.capture3({ "LANG" => "C" }, WHOIS_BIN, domain)
  if status.success? && !out.strip.empty?
    File.write(cache_file, out)
    out
  else
    File.write(cache_file, "ERROR\n")
    nil
  end
end

def parse_whois(raw)
  return nil if raw.nil? || raw.start_with?("ERROR")
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
  # DENIC (.de) and SWITCH (.ch) use "Status: connect" or "Status: active"
  # for registered domains; "Status: free" for available ones.
  has_status_connect = raw =~ /^\s*Status:\s*(?:connect|active)\b/i
  status =
    if expt
      expt < Time.now ? "expired" : "active"
    elsif registrar || has_status_connect
      "active"
    elsif raw =~ /redacted for privacy|REDACTED FOR PRIVACY/i
      "private"
    elsif raw =~ /^\s*(?:No match for|NOT FOUND|No Data Found|Domain not found|is free|Status:\s*free|Status:\s*AVAILABLE|This domain is available)/i
      "available"
    else
      "unknown"
    end
  { status: status, expires_at: expt&.iso8601, registrar: registrar, source: "whois" }
end

def classify(domain)
  # Skip things we shouldn't even try to register (subdomains, hostnames,
  # UUIDs, gov/edu, etc.). These come from git commit-config noise.
  return { status: "non_registrable", expires_at: nil, registrar: nil, source: "filter" } if non_registrable?(domain)

  # 1. Try RDAP. Returns nil if RDAP can't classify (404 from rdap.org, or
  #    response with no expiry/status), so we fall through to whois.
  rdap = fetch_rdap(domain)
  parsed = parse_rdap(rdap) if rdap
  return parsed if parsed && parsed[:status] != "unknown"

  # 2. Fall back to whois.
  raw = fetch_whois(domain)
  parsed = parse_whois(raw)
  parsed || { status: "unknown", expires_at: nil, registrar: nil, source: "none" }
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

# Add a column to track which source classified each domain
begin
  db.execute("ALTER TABLE email_domains ADD COLUMN status_source TEXT")
rescue SQLite3::SQLException => e
  raise unless e.message =~ /duplicate column/
end

# Re-process anything not confidently 'active' or 'expired' from a real
# whois lookup, plus anything previously classified by RDAP (an earlier
# parser was over-eager: RDAP 404 was tagged 'available' when in fact the
# TLD just doesn't have RDAP coverage via rdap.org).
todo = db.execute(<<~SQL).map { |r| r["domain"] }
  SELECT domain FROM email_domains
  WHERE kind = 'custom'
    AND (
      whois_status IN ('unknown','error','no_whois_tool','available')
      OR whois_status IS NULL
      OR status_source = 'rdap'
    )
  ORDER BY domain
SQL
todo = todo.first(LIMIT) if LIMIT
puts "#{todo.size} domains to (re)classify"

upd = db.prepare(<<~SQL)
  UPDATE email_domains
  SET whois_status=?, whois_expires_at=?, whois_registrar=?, status_source=?, checked_at=datetime('now')
  WHERE domain=?
SQL

counts = Hash.new(0)
by_source = Hash.new(0)
todo.each_with_index do |d, i|
  res = classify(d)
  counts[res[:status]] += 1
  by_source[res[:source]] += 1
  upd.execute(res[:status], res[:expires_at], res[:registrar], res[:source], d)
  print "\r[#{i + 1}/#{todo.size}] #{counts.map { |k, v| "#{k}=#{v}" }.join(' ')} | src #{by_source.map { |k, v| "#{k}=#{v}" }.join(' ')}"
end
upd.close
puts
puts
puts "final distribution:"
db.execute("SELECT whois_status, COUNT(*) AS n FROM email_domains WHERE kind='custom' GROUP BY whois_status ORDER BY n DESC").each do |r|
  printf "  %-12s %d\n", r["whois_status"] || "(null)", r["n"]
end
