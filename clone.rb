#!/usr/bin/env ruby
# Ground-truth last commit on the default branch via a shallow clone.
# pushed_at from the API is any-branch and can be stale; this is the number
# we actually trust for "time since last commit". Results cached under
# cache/clone until --refresh is requested.
#
# Clones are --depth 1 --bare --filter=blob:none into a temp dir and removed
# immediately after reading the commit date.
#
# Usage: ruby clone.rb [--refresh] [--all] [--failures FILE] [LIMIT]

require "json"
require "sqlite3"
require "fileutils"
require "digest"
require "tmpdir"
require "open3"
require "time"
require "optparse"
require_relative "database"
require_relative "lookup_failures"

WORKDIR = __dir__
DB_PATH = Bernies.database_path
CACHE   = File.join(WORKDIR, "cache", "clone")
options = {}
OptionParser.new do |parser|
  parser.on("--refresh") { options[:refresh] = true }
  parser.on("--all") { options[:all] = true }
  parser.on("--failures FILE") { |path| options[:failures] = path }
end.parse!
REFRESH = !!options[:refresh]
ALL = !!options[:all]
LIMIT = ARGV[0]&.to_i

CLONE_HOSTS = %w[github.com gitlab.com codeberg.org gitea.com sr.ht git.sr.ht]
CloneFailure = Struct.new(:url, :status, :host_status, :resolved_url, :reason, keyword_init: true)

FileUtils.mkdir_p(CACHE)

def cache_path(url)
  File.join(CACHE, "#{Digest::SHA256.hexdigest(url)[0, 32]}.json")
end

def shallow_clone(url, refresh: REFRESH)
  path = cache_path(url)
  if !refresh && File.exist?(path)
    body = File.read(path)
    return JSON.parse(body) unless body == "null"
  end

  result = nil
  Dir.mktmpdir("bernies-") do |dir|
    env = { "GIT_TERMINAL_PROMPT" => "0", "GIT_ASKPASS" => "/bin/true", "SSH_ASKPASS" => "/bin/true" }
    cfg = ["-c", "credential.helper=", "-c", "core.askPass=", "-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=30"]
    _, _, st = Open3.capture3(env, "git", *cfg, "clone", "--quiet", "--depth", "1", "--bare",
                               "--filter=blob:none", "#{url}.git", dir)
    unless st.success?
      _, _, st = Open3.capture3(env, "git", *cfg, "clone", "--quiet", "--depth", "1", "--bare",
                                 "--filter=blob:none", url, dir)
    end
    if st.success?
      out, = Open3.capture2(env, "git", "-C", dir, "log", "-1", "--format=%cI%x09%H")
      date, sha = out.strip.split("\t", 2)
      result = { "last_commit_at" => date, "last_commit_sha" => sha }
    end
  end

  return CloneFailure.new(url: url, reason: "clone_failed") unless result

  File.write(path, JSON.generate(result))
  result
rescue => e
  warn "  #{url}: #{e.class}: #{e.message}"
  CloneFailure.new(url: url, reason: "clone_error")
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
failures = Bernies::LookupFailures.new(db, "clone")

# Prioritise repos that look stale or unclassified so the expensive step
# moves the needle first.
urls = db.execute(<<~SQL).map { |r| r["repository_url"] }
  SELECT repository_url FROM repos
  WHERE #{REFRESH ? "1=1" : "(cloned_at IS NULL OR EXISTS (SELECT 1 FROM lookup_failures f " \
    "WHERE f.collector='clone' AND f.kind='repository' AND f.identifier=repos.repository_url))"}
    AND host IN (#{CLONE_HOSTS.map { |h| "'#{h}'" }.join(",")})
    #{ALL ? "" : "AND (bucket IS NULL OR bucket <> 'active')"}
  ORDER BY (bucket IN ('dead','unknown','dormant')) DESC,
           COALESCE(pushed_at,'') ASC
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{urls.size} repos to shallow-clone"

upd = db.prepare("UPDATE repos SET last_commit_at=?, last_commit_sha=?, cloned_at=? WHERE repository_url=?")
now = Time.now.utc.iso8601
hit = miss = 0
urls.each_with_index do |url, i|
  r = shallow_clone(url, refresh: REFRESH || failures.recorded?("repository", url))
  if r.is_a?(Hash)
    upd.execute(r["last_commit_at"], r["last_commit_sha"], now, url)
    failures.clear("repository", url)
    hit += 1
  else
    failures.record("repository", url, r, repository_url: url)
    puts ; puts "miss: #{url}: #{r.reason}"
    miss += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "cloned #{hit}, failed #{miss}"
Bernies::LookupFailures.export(db, options[:failures], collector: "clone") if options[:failures]
