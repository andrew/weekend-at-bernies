#!/usr/bin/env ruby
# Ground-truth last commit on the default branch via a shallow clone.
# pushed_at from the API is any-branch and can be stale; this is the number
# we actually trust for "time since last commit". Results cached under
# cache/clone so each repo is only cloned once.
#
# Clones are --depth 1 --bare --filter=blob:none into a temp dir and removed
# immediately after reading the commit date.
#
# Usage: ruby clone.rb [LIMIT]
#        ruby clone.rb --all        # ignore LIMIT, do every uncached repo

require "json"
require "sqlite3"
require "fileutils"
require "digest"
require "tmpdir"
require "open3"
require "time"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "clone")
LIMIT   = ARGV.reject { |a| a.start_with?("--") }.first&.to_i
ALL     = ARGV.include?("--all")

CLONE_HOSTS = %w[github.com gitlab.com codeberg.org gitea.com sr.ht git.sr.ht]

FileUtils.mkdir_p(CACHE)

def cache_path(url)
  File.join(CACHE, "#{Digest::SHA256.hexdigest(url)[0, 32]}.json")
end

def shallow_clone(url)
  path = cache_path(url)
  if File.exist?(path)
    body = File.read(path)
    return body == "null" ? nil : JSON.parse(body)
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

  File.write(path, result ? JSON.generate(result) : "null")
  result
rescue => e
  warn "  #{url}: #{e.class}: #{e.message}"
  nil
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

# Prioritise repos that look stale or unclassified so the expensive step
# moves the needle first.
urls = db.execute(<<~SQL).map { |r| r["repository_url"] }
  SELECT repository_url FROM repos
  WHERE cloned_at IS NULL
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
  r = shallow_clone(url)
  if r
    upd.execute(r["last_commit_at"], r["last_commit_sha"], now, url)
    hit += 1
  else
    upd.execute(nil, nil, now, url)
    miss += 1
  end
  print "\r[#{i + 1}/#{urls.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "cloned #{hit}, failed #{miss}"
