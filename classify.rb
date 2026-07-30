#!/usr/bin/env ruby
# Bucket each repo into active / dormant / dead / unknown and record the
# signals that drove the decision. Thresholds are first-pass guesses; the
# point is to get everything into sqlite so the cutoffs can be argued over
# with SELECTs rather than re-running collection.
#
#   active   development is happening (regular human commits or recent
#            release plus responsive maintainers)
#   dormant  low or no development, but someone with write access is still
#            around: closing issues, merging PRs, or otherwise responding
#   dead     archived, long-unpushed, or no maintainer activity of any kind
#            in the past year
#   unknown  not enough data from commits/issues to call it
#
# Usage: ruby classify.rb

require "sqlite3"
require "date"
require "time"
require_relative "database"

WORKDIR = __dir__
DB_PATH = Bernies.database_path

ACTIVE_COMMITS_PER_YEAR = 12
STALE_PUSH_DAYS         = 730
STALE_RELEASE_DAYS      = 365

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

today = Date.today

def days_since(ts, today)
  return nil if ts.nil? || ts.empty?
  (today - Date.parse(ts)).to_i
rescue
  nil
end

latest_release = {}
db.execute("SELECT repository_url, MAX(latest_release_at) AS r FROM packages WHERE repository_url IS NOT NULL GROUP BY repository_url") do |row|
  latest_release[row["repository_url"]] = row["r"]
end

pkg_status = {}
db.execute("SELECT repository_url, GROUP_CONCAT(DISTINCT status) AS s FROM packages WHERE status IS NOT NULL AND status <> '' GROUP BY repository_url") do |row|
  pkg_status[row["repository_url"]] = row["s"]
end

upd = db.prepare <<~SQL
  UPDATE repos SET days_since_release=?, days_since_push=?, days_since_commit=?, bucket=?, signals=?, classified_at=?
  WHERE repository_url=?
SQL

now    = Time.now.utc.iso8601
counts = Hash.new(0)

db.execute("SELECT * FROM repos") do |r|
  url = r["repository_url"]
  ds_push    = days_since(r["pushed_at"], today)
  ds_commit  = days_since(r["last_commit_at"], today)
  ds_release = days_since(latest_release[url], today)
  ds_code    = ds_commit || ds_push

  py_commits    = r["past_year_commits"]
  py_bots       = r["past_year_bot_commits"] || 0
  human_commits = py_commits ? [py_commits - py_bots, 0].max : nil
  active_maint  = r["active_maintainers_count"]
  closed        = (r["past_year_issues_closed"] || 0) + (r["past_year_prs_closed"] || 0)
  merged        = r["past_year_prs_merged"] || 0

  have_commits = !r["commits_synced_at"].nil?
  have_issues  = !r["issues_synced_at"].nil?

  signals = []
  signals << "archived"                       if r["archived"] == 1
  signals << "repo:#{r['repo_status']}"       if r["repo_status"] && !r["repo_status"].empty?
  signals << "pkg:#{pkg_status[url]}"         if pkg_status[url]
  signals << "commit:#{ds_commit}d"           if ds_commit
  signals << "push:#{ds_push}d"               if ds_push && !ds_commit
  signals << "release:#{ds_release}d"         if ds_release
  signals << "commits:#{human_commits}"       if have_commits
  signals << "active_maint:#{active_maint}"   if have_issues
  signals << "closed:#{closed}"               if have_issues
  signals << "merged:#{merged}"               if have_issues
  signals << "adv:#{r['advisories_count']}/#{r['unpatched_advisories_count']}" if (r["advisories_count"] || 0) > 0

  recent_release = ds_release && ds_release <= STALE_RELEASE_DAYS
  recent_commit  = ds_commit && ds_commit <= STALE_RELEASE_DAYS

  # Positive signals only. Absence of commits is not evidence of absence.
  someone_home = (human_commits && human_commits > 0) ||
                 (active_maint && active_maint > 0) ||
                 (have_issues && (closed > 0 || merged > 0)) ||
                 recent_release || recent_commit

  # We only have grounds to say "nobody is responding" if someone actually
  # asked: issues or PRs were filed in the past year and nobody with write
  # access reacted. No issues filed + no response proves nothing.
  asked = have_issues && (r["past_year_issues"].to_i + r["past_year_prs"].to_i) > 0
  confirmed_unresponsive = asked && !someone_home

  bucket =
    if r["archived"] == 1
      "dead"
    elsif confirmed_unresponsive
      "dead"
    elsif someone_home
      if (human_commits && human_commits >= ACTIVE_COMMITS_PER_YEAR) || recent_release
        "active"
      else
        "dormant"
      end
    elsif recent_commit || (ds_code && ds_code <= STALE_RELEASE_DAYS)
      "active"
    else
      "unknown"
    end

  upd.execute(ds_release, ds_push, ds_commit, bucket, signals.join(" "), now, url)
  counts[bucket] += 1
end
upd.close

total = counts.values.sum
puts "classified #{total} repos:"
%w[active dormant dead unknown].each do |b|
  c = counts[b]
  pct = total.zero? ? 0 : (100.0 * c / total)
  printf "  %-8s %6d  (%.1f%%)\n", b, c, pct
end
