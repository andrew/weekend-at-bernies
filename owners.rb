#!/usr/bin/env ruby
# Populate the owners table with per-owner metadata: org vs user, global
# repository count, public contact channels, funding links. Reads
# cache/packages first since the packages.ecosyste.ms listing embeds
# repo_metadata.owner_record for free, then falls back to a per-owner fetch
# from repos.ecosyste.ms for whatever is left. Cached under cache/owners.
#
# Usage: ruby owners.rb [LIMIT]   (LIMIT applies to the API fallback only)

require "sqlite3"
require "set"
require "uri"
require "json"
require "fileutils"
require_relative "http"

WORKDIR        = __dir__
DB_PATH        = File.join(WORKDIR, "bernies.db")
PACKAGES_CACHE = File.join(WORKDIR, "cache", "packages")
REPOS_CACHE    = File.join(WORKDIR, "cache", "repos")
OWNERS_CACHE   = File.join(WORKDIR, "cache", "owners")
CONN           = conn("https://repos.ecosyste.ms")
LIMIT          = ARGV[0]&.to_i

FileUtils.mkdir_p(OWNERS_CACHE)

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
db.execute_batch <<~SQL
  CREATE TABLE IF NOT EXISTS owners (
    host                TEXT NOT NULL,
    login               TEXT NOT NULL,
    kind                TEXT,
    name                TEXT,
    description         TEXT,
    email               TEXT,
    website             TEXT,
    twitter             TEXT,
    company             TEXT,
    location            TEXT,
    html_url            TEXT,
    repositories_count  INTEGER,
    total_stars         INTEGER,
    followers           INTEGER,
    following           INTEGER,
    funding_links       TEXT,
    last_synced_at      TEXT,
    owner_url_path      TEXT,
    owners_synced_at    TEXT,
    PRIMARY KEY (host, login)
  );
  CREATE INDEX IF NOT EXISTS idx_owners_kind ON owners(kind);
SQL

upsert = db.prepare <<~SQL
  INSERT INTO owners (
    host, login, kind, name, description, email, website, twitter, company, location,
    html_url, repositories_count, total_stars, followers, following, funding_links,
    last_synced_at, owner_url_path, owners_synced_at
  ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,datetime('now'))
  ON CONFLICT(host, login) DO UPDATE SET
    kind=excluded.kind, name=excluded.name, description=excluded.description,
    email=excluded.email, website=excluded.website, twitter=excluded.twitter,
    company=excluded.company, location=excluded.location, html_url=excluded.html_url,
    repositories_count=excluded.repositories_count, total_stars=excluded.total_stars,
    followers=excluded.followers, following=excluded.following,
    funding_links=excluded.funding_links, last_synced_at=excluded.last_synced_at,
    owner_url_path=excluded.owner_url_path, owners_synced_at=datetime('now')
SQL

mark_missing = db.prepare(<<~SQL)
  INSERT OR IGNORE INTO owners (host, login, owners_synced_at)
  VALUES (?, ?, datetime('now'))
SQL

def host_from_url(url)
  url && URI.parse(url).host
rescue URI::InvalidURIError
  nil
end

def write_owner(upsert, host, login, rec)
  return false unless rec
  funding = rec["funding_links"].is_a?(Array) ? rec["funding_links"].join(",") : nil
  owner_url_path = rec["owner_url"] ? URI.parse(rec["owner_url"]).path : nil
  upsert.execute(
    host, login,
    rec["kind"], rec["name"], rec["description"], rec["email"], rec["website"],
    rec["twitter"], rec["company"], rec["location"], rec["html_url"],
    rec["repositories_count"], rec["total_stars"], rec["followers"], rec["following"],
    funding, rec["last_synced_at"], owner_url_path
  )
  true
end

# ---- pass 1: harvest owner_record from cached packages ----
puts "scanning cache/packages for embedded owner_record..."
files = Dir[File.join(PACKAGES_CACHE, "*.json")]
seen = Set.new
hit  = 0
files.each_with_index do |f, i|
  body = File.read(f)
  next if body == "null"
  data = JSON.parse(body)
  pkgs = data.is_a?(Hash) ? data["packages"] : data
  next unless pkgs
  pkgs.each do |p|
    rm  = p["repo_metadata"] or next
    rec = rm["owner_record"] or next
    host = host_from_url(rm.dig("host", "url"))
    login = rec["login"] || rm["owner"]
    next unless host && login
    key = [host, login]
    next if seen.include?(key)
    seen.add(key)
    write_owner(upsert, host, login, rec)
    hit += 1
  end
  print "\r[#{i + 1}/#{files.size}] cache owners written: #{hit}"
end
puts

# ---- pass 2: API fallback for the remainder ----
synced = db
  .execute("SELECT host, login FROM owners WHERE owners_synced_at IS NOT NULL AND kind IS NOT NULL")
  .map { |r| [r["host"], r["login"]] }
  .to_set

rows = db.execute(<<~SQL)
  SELECT host, owner, MIN(repository_url) AS repository_url
  FROM repos
  WHERE owner IS NOT NULL AND repository_url IS NOT NULL
  GROUP BY host, owner
  ORDER BY (host='github.com') DESC, host, owner
SQL

todo = rows.reject { |r| synced.include?([r["host"], r["owner"]]) }
todo = todo.first(LIMIT) if LIMIT

puts "API fallback: #{todo.size} owners not in cache (#{synced.size} already filled)"

api_hit = api_miss = norepo = 0
todo.each_with_index do |r, i|
  host, login = r["host"], r["owner"]
  repo = cached_get(CONN, "/api/v1/repositories/lookup", { url: r["repository_url"] }, REPOS_CACHE)
  if repo.nil? || repo["owner_url"].to_s.empty?
    norepo += 1
    mark_missing.execute(host, login)
  else
    path = URI.parse(repo["owner_url"]).path
    rec = cached_get(CONN, path, {}, OWNERS_CACHE)
    if rec.nil?
      api_miss += 1
      mark_missing.execute(host, login)
    else
      write_owner(upsert, host, login, rec)
      api_hit += 1
    end
  end
  print "\r[#{i + 1}/#{todo.size}] hit=#{api_hit} miss=#{api_miss} norepo=#{norepo}"
end
upsert.close
mark_missing.close
puts
populated = db.get_first_value("SELECT COUNT(*) FROM owners WHERE kind IS NOT NULL")
unknown   = db.get_first_value("SELECT COUNT(*) FROM owners WHERE kind IS NULL")
puts "owners table: #{populated} populated, #{unknown} unknown"
