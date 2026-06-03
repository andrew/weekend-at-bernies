#!/usr/bin/env ruby
# Replace whois-based domain risk classification with Domainr's status API.
# Same approach pypi/warehouse uses for account-recovery email checks
# (see warehouse/accounts/services.py DomainrDomainStatusService).
#
# Domainr returns a space-separated status string per domain. Key values:
#
#   active        registered, in use or parked normally       (safe)
#   parked        registered, parked page                     (safe)
#   claimed       registered                                  (safe)
#   marketed      registered, listed for sale                 (elevated risk: someone selling)
#   priced        same as marketed with a price tag           (elevated)
#   transferable  registered, can be transferred              (elevated)
#   expiring      registered, expiry window                   (elevated)
#   deleting      in registry redemption / deletion phase     (high risk: about to drop)
#   inactive      not registered                              (high risk: anyone can register)
#   available     not registered, registerable                (high risk: anyone can register)
#   unknown       couldn't determine                          (inconclusive)
#
# Auth: set either DOMAINR_CLIENT_ID (direct api.domainr.com) or
# RAPIDAPI_KEY (domainr.p.rapidapi.com). Free tier on either path is enough
# for our ~600 domains.
#
# Usage: ruby domain_status.rb [LIMIT]

require "sqlite3"
require "set"
require "fileutils"
require_relative "http"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "emails", "domainr")
LIMIT   = ARGV[0]&.to_i

FileUtils.mkdir_p(CACHE)

DIRECT_ID   = ENV["DOMAINR_CLIENT_ID"]
RAPIDAPI_KEY = ENV["RAPIDAPI_KEY"]

if DIRECT_ID
  BASE   = "https://api.domainr.com"
  HEADERS = {}
elsif RAPIDAPI_KEY
  BASE   = "https://domainr.p.rapidapi.com"
  HEADERS = { "X-RapidAPI-Key" => RAPIDAPI_KEY, "X-RapidAPI-Host" => "domainr.p.rapidapi.com" }
else
  abort "set DOMAINR_CLIENT_ID (direct api.domainr.com) or RAPIDAPI_KEY (via RapidAPI). Free signup at https://domainr.com/docs/api or https://rapidapi.com/domainr/api/domainr"
end

CONN = Faraday.new(url: BASE, headers: HEADERS.merge("User-Agent" => UA, "Accept" => "application/json")) do |f|
  f.request :retry,
    max: 4, interval: 1, backoff_factor: 2,
    retry_statuses: [429, 500, 502, 503, 504],
    methods: [:get],
    exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, Faraday::TimeoutError]
  f.response :follow_redirects, limit: 3
  f.options.timeout = 10
  f.options.open_timeout = 5
  f.adapter Faraday.default_adapter
end

def fetch_status(domain)
  params = { domain: domain }
  params[:client_id] = DIRECT_ID if DIRECT_ID
  cached_get(CONN, "/v2/status", params, CACHE)
end

# Map Domainr status tokens to a risk band for downstream queries
RISK_BANDS = {
  "active"       => "safe",
  "parked"       => "safe",
  "claimed"      => "safe",
  "dpml"         => "safe",
  "reserved"     => "safe",
  "marketed"     => "elevated",
  "priced"       => "elevated",
  "transferable" => "elevated",
  "expiring"     => "elevated",
  "deleting"     => "high",
  "inactive"     => "high",
  "available"    => "high",
  "disallowed"   => "n/a",
  "tld"          => "n/a",
  "suffix"       => "n/a",
  "zone"         => "n/a",
  "unknown"      => "inconclusive",
}
RISK_RANK = { "high" => 3, "elevated" => 2, "safe" => 1, "n/a" => 0, "inconclusive" => 0 }

def overall_risk(tokens)
  tokens.map { |t| RISK_BANDS[t] || "inconclusive" }.max_by { |b| RISK_RANK[b] || 0 } || "inconclusive"
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

%w[domainr_status risk_band domainr_synced_at].each do |col|
  begin
    db.execute("ALTER TABLE email_domains ADD COLUMN #{col} TEXT")
  rescue SQLite3::SQLException => e
    raise unless e.message =~ /duplicate column/
  end
end

todo = db.execute(<<~SQL).map { |r| r["domain"] }
  SELECT domain FROM email_domains
  WHERE kind = 'custom' AND (domainr_synced_at IS NULL OR domainr_status IS NULL)
  ORDER BY domain
SQL
todo = todo.first(LIMIT) if LIMIT
puts "#{todo.size} domains to classify via Domainr"

upd = db.prepare(<<~SQL)
  UPDATE email_domains
  SET domainr_status=?, risk_band=?, domainr_synced_at=datetime('now')
  WHERE domain=?
SQL

counts = Hash.new(0)
todo.each_with_index do |d, i|
  resp = fetch_status(d)
  if resp.nil? || resp["status"].nil? || resp["status"].empty?
    upd.execute("error", "inconclusive", d)
    counts["error"] += 1
  else
    tokens = resp["status"][0]["status"].to_s.split
    band = overall_risk(tokens)
    upd.execute(tokens.join(" "), band, d)
    counts[band] += 1
  end
  print "\r[#{i + 1}/#{todo.size}] #{counts.map { |k, v| "#{k}=#{v}" }.join(' ')}"
end
upd.close
puts
puts
puts "risk band distribution:"
db.execute("SELECT COALESCE(risk_band, '(null)') AS band, COUNT(*) AS n FROM email_domains WHERE kind='custom' GROUP BY band ORDER BY n DESC").each do |r|
  printf "  %-12s %d\n", r["band"], r["n"]
end
