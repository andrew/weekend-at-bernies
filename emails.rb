#!/usr/bin/env ruby
# Collect commit email addresses for individual bernie-holders and classify
# their domains by takeover risk. Two passes:
#
#   1. For each user, pull commits.ecosyste.ms /committers/{login} to get
#      every email address they've committed under. Insert one row per
#      (user, email) into commit_emails.
#
#   2. For each distinct domain (skipping free webmail and github noreply),
#      check DNS resolution, MX records, and registry expiry via whois.
#      Cache whois responses on disk; throttle 5s/query to avoid blocks.
#
# The threat model: an attacker who buys an expired domain that a maintainer
# committed under (and likely still has set as their GitHub recovery email)
# can request a password reset and take over the account. This script
# surfaces the at-risk cohort.
#
# Usage: ruby emails.rb [LIMIT]   (LIMIT applies to step 1 users)

require "sqlite3"
require "set"
require "json"
require "time"
require "digest"
require "resolv"
require "open3"
require "fileutils"
require_relative "http"

WORKDIR          = __dir__
DB_PATH          = File.join(WORKDIR, "bernies.db")
COMMITTERS_CACHE = File.join(WORKDIR, "cache", "emails", "committers")
WHOIS_CACHE      = File.join(WORKDIR, "cache", "emails", "whois")
COMMITS_CONN     = conn("https://commits.ecosyste.ms")
LIMIT            = ARGV[0]&.to_i
WHOIS_DELAY      = 5

FREE_WEBMAIL = %w[
  gmail.com googlemail.com outlook.com hotmail.com hotmail.co.uk hotmail.fr
  hotmail.de live.com yahoo.com yahoo.co.uk yahoo.fr yahoo.de yahoo.co.jp
  ymail.com icloud.com me.com mac.com protonmail.com proton.me pm.me
  fastmail.com fastmail.fm aol.com gmx.com gmx.de gmx.net mail.com mail.ru
  yandex.ru yandex.com zoho.com qq.com 163.com 126.com sina.com hey.com
  posteo.net tutanota.com tutamail.com cock.li riseup.net duck.com web.de
  t-online.de hushmail.com inbox.com rediffmail.com
].to_set

GITHUB_NOREPLY = /\.noreply\.github\.com\z/

FileUtils.mkdir_p(COMMITTERS_CACHE)
FileUtils.mkdir_p(WHOIS_CACHE)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS commit_emails (
    host   TEXT NOT NULL,
    login  TEXT NOT NULL,
    email  TEXT NOT NULL,
    domain TEXT NOT NULL,
    PRIMARY KEY (host, login, email)
  );
  CREATE INDEX IF NOT EXISTS idx_commit_emails_domain ON commit_emails(domain);
  CREATE INDEX IF NOT EXISTS idx_commit_emails_login  ON commit_emails(host, login);

  CREATE TABLE IF NOT EXISTS email_domains (
    domain           TEXT PRIMARY KEY,
    kind             TEXT,
    resolves         INTEGER,
    has_mx           INTEGER,
    mx_count         INTEGER,
    whois_status     TEXT,
    whois_expires_at TEXT,
    whois_registrar  TEXT,
    checked_at       TEXT
  );
SQL

def classify_kind(domain)
  return "github_noreply" if domain =~ GITHUB_NOREPLY
  return "free_webmail"   if FREE_WEBMAIL.include?(domain.downcase)
  "custom"
end

def fetch_committer(login)
  cached_get(
    COMMITS_CONN,
    "/api/v1/hosts/GitHub/committers/#{login}",
    {},
    COMMITTERS_CACHE
  )
end

def dns_check(domain)
  resolves = false
  mx = []
  Resolv::DNS.open do |dns|
    dns.timeouts = 3
    addrs = dns.getresources(domain, Resolv::DNS::Resource::IN::A).to_a
    resolves = !addrs.empty?
    mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX).to_a
  end
  { resolves: resolves || !mx.empty?, has_mx: !mx.empty?, mx_count: mx.size }
rescue Resolv::ResolvError, Resolv::ResolvTimeout, IOError
  { resolves: false, has_mx: false, mx_count: 0 }
end

def parse_whois(raw)
  return { status: "error", expires_at: nil, registrar: nil } if raw.start_with?("ERROR")

  exp = nil
  raw.each_line do |line|
    if line =~ /(?:Registry Expiry Date|Registrar Registration Expiration Date|Expiration Date|Expiry Date|Expires On|paid-till|expire)\s*:\s*(.+)/i
      exp = $1.strip
      break
    end
  end

  registrar = nil
  raw.each_line do |line|
    if line =~ /^\s*Registrar\s*:\s*(.+)/i
      registrar = $1.strip
      break
    end
  end

  status =
    if raw =~ /No match for|NOT FOUND|No Data Found|Domain not found|is free|Status: free|Status: AVAILABLE/i
      "available"
    elsif raw =~ /redacted for privacy|REDACTED FOR PRIVACY/i && !exp
      "private"
    elsif exp
      expt = (Time.parse(exp) rescue nil)
      expt && expt < Time.now ? "expired" : "active"
    else
      "unknown"
    end

  expires_at = (Time.parse(exp).iso8601 rescue nil) if exp
  { status: status, expires_at: expires_at, registrar: registrar }
end

def whois_check(domain)
  cache_file = File.join(WHOIS_CACHE, "#{Digest::SHA256.hexdigest(domain)[0, 32]}.txt")
  raw =
    if File.exist?(cache_file)
      File.read(cache_file)
    else
      sleep WHOIS_DELAY
      out, _err, status = Open3.capture3({ "LANG" => "C" }, "whois", domain)
      if status.success? && !out.strip.empty?
        File.write(cache_file, out)
        out
      else
        File.write(cache_file, "ERROR\n")
        "ERROR\n"
      end
    end
  parse_whois(raw)
rescue Errno::ENOENT
  { status: "no_whois_tool", expires_at: nil, registrar: nil }
end

# ---------- pass 1: fetch committer emails ----------

users = db.execute(<<~SQL).map { |r| r["login"] }
  SELECT DISTINCT o.login FROM owners o
  JOIN repos r ON r.host=o.host AND r.owner=o.login
  WHERE o.kind='user' AND o.host='github.com'
    AND r.bucket IN ('dead','dormant')
  ORDER BY o.login
SQL

done = db
  .execute("SELECT DISTINCT login FROM commit_emails")
  .map { |r| r["login"] }
  .to_set

todo_users = users.reject { |l| done.include?(l) }
todo_users = todo_users.first(LIMIT) if LIMIT
puts "step 1: fetch committer emails for #{todo_users.size} users (#{done.size} done)"

ins = db.prepare("INSERT OR IGNORE INTO commit_emails (host, login, email, domain) VALUES (?,?,?,?)")
hit = miss = no_email = 0
todo_users.each_with_index do |login, i|
  rec = fetch_committer(login)
  if rec.nil?
    miss += 1
  else
    emails = (rec["emails"] || []).map { |e| e.to_s.downcase.strip }.reject(&:empty?).uniq
    if emails.empty?
      no_email += 1
    else
      emails.each do |e|
        next unless e.include?("@")
        dom = e.split("@", 2).last
        next if dom.nil? || dom.empty?
        ins.execute("github.com", login, e, dom)
      end
    end
    hit += 1
  end
  print "\r[#{i + 1}/#{todo_users.size}] hit=#{hit} no_email=#{no_email} miss=#{miss}"
end
ins.close
puts

# ---------- pass 2: classify + DNS + whois per distinct domain ----------

domains = db.execute(<<~SQL).map { |r| r["domain"] }
  SELECT DISTINCT domain FROM commit_emails
SQL

already = db
  .execute("SELECT domain FROM email_domains WHERE checked_at IS NOT NULL")
  .map { |r| r["domain"] }
  .to_set

todo_domains = domains.reject { |d| already.include?(d) }
puts "step 2: classify/check #{todo_domains.size} domains (#{already.size} done)"

upsert = db.prepare <<~SQL
  INSERT INTO email_domains (
    domain, kind, resolves, has_mx, mx_count,
    whois_status, whois_expires_at, whois_registrar, checked_at
  ) VALUES (?,?,?,?,?,?,?,?,datetime('now'))
  ON CONFLICT(domain) DO UPDATE SET
    kind=excluded.kind, resolves=excluded.resolves, has_mx=excluded.has_mx,
    mx_count=excluded.mx_count, whois_status=excluded.whois_status,
    whois_expires_at=excluded.whois_expires_at,
    whois_registrar=excluded.whois_registrar, checked_at=datetime('now')
SQL

bg = bgm = bgw = bge = 0
todo_domains.each_with_index do |domain, i|
  kind = classify_kind(domain)

  if kind == "github_noreply" || kind == "free_webmail"
    upsert.execute(domain, kind, nil, nil, nil, nil, nil, nil)
  else
    dns   = dns_check(domain)
    whois = whois_check(domain)
    upsert.execute(
      domain, kind,
      dns[:resolves] ? 1 : 0, dns[:has_mx] ? 1 : 0, dns[:mx_count],
      whois[:status], whois[:expires_at], whois[:registrar]
    )
    bg  += 1
    bgm += 1 if dns[:has_mx]
    bgw += 1 if whois[:status] == "active"
    bge += 1 if whois[:status] == "available" || whois[:status] == "expired"
  end

  print "\r[#{i + 1}/#{todo_domains.size}] custom=#{bg} with_mx=#{bgm} whois_active=#{bgw} expired/available=#{bge}"
end
upsert.close
puts

puts "commit_emails: #{db.get_first_value("SELECT COUNT(*) FROM commit_emails")}"
puts "email_domains: #{db.get_first_value("SELECT COUNT(*) FROM email_domains")}"
