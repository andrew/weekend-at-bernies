#!/usr/bin/env ruby
# Codebase size and shape for non-active repos. Shallow-clone the working
# tree, run `brief` (toolchain summary) and `scc` (LOC + complexity) on the
# primary source dir, count top-level entry points, grep README/manifest
# for deprecation pointers, then delete the clone. Results cached under
# cache/size and the brief JSON under cache/brief.
#
# Usage: ruby size.rb [LIMIT] [--all] [--keep]

require "json"
require "sqlite3"
require "fileutils"
require "digest"
require "tmpdir"
require "open3"
require "time"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "size")
BRIEF   = File.join(WORKDIR, "cache", "brief")
LIMIT   = ARGV.grep(/\A\d+\z/).first&.to_i
ALL     = ARGV.include?("--all")
KEEP    = ARGV.include?("--keep")
ECO     = (i = ARGV.index("--ecosystem")) && ARGV[i + 1]
BUCKET  = (i = ARGV.index("--bucket")) && ARGV[i + 1]

CLONE_HOSTS = %w[github.com gitlab.com codeberg.org gitea.com sr.ht git.sr.ht]
NATIVE_LANGS = %w[C C++ Rust Java Objective-C Objective-C++ Go Zig Assembly]
DEPRECATION_RE = /deprecat|unmaintained|no longer maintained|use .{1,40} instead|superseded by|abandoned/i

SOURCE_DIRS = {
  "rubygems"  => %w[lib],
  "npm"       => %w[src lib],
  "pypi"      => %w[src],
  "cargo"     => %w[src],
  "packagist" => %w[src lib],
  "hex"       => %w[lib],
  "nuget"     => %w[src],
  "go"        => %w[.],
  "maven"     => %w[src/main],
}

FileUtils.mkdir_p(CACHE)
FileUtils.mkdir_p(BRIEF)

def hkey(url) = Digest::SHA256.hexdigest(url)[0, 32]

def run(*cmd, dir: nil)
  out, _, st = Open3.capture3(*cmd, chdir: dir || Dir.pwd)
  st.success? ? out : nil
end

def clone(url, dir)
  env = { "GIT_TERMINAL_PROMPT" => "0", "GIT_ASKPASS" => "/bin/true", "SSH_ASKPASS" => "/bin/true" }
  cfg = ["-c", "credential.helper=", "-c", "core.askPass=", "-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=30"]
  _, _, st = Open3.capture3(env, "git", *cfg, "clone", "--quiet", "--depth", "1", "#{url}.git", dir)
  return true if st.success?
  _, _, st = Open3.capture3(env, "git", *cfg, "clone", "--quiet", "--depth", "1", url, dir)
  st.success?
end

def source_dir(root, ecosystems)
  ecosystems.each do |eco|
    (SOURCE_DIRS[eco] || []).each do |d|
      path = File.join(root, d)
      return path if Dir.exist?(path) && !Dir.empty?(path)
    end
  end
  root
end

def entry_points(root, src, ecosystems)
  if ecosystems.include?("npm")
    pkg = File.join(root, "package.json")
    if File.exist?(pkg)
      j = JSON.parse(File.read(pkg)) rescue {}
      exp = j["exports"]
      return exp.is_a?(Hash) ? exp.keys.size : 1 if exp
    end
  end
  Dir.children(src).count { |f| File.file?(File.join(src, f)) && f !~ /^(index|__init__|mod|lib|main)\b/i }
rescue
  nil
end

def readme_excerpt(root)
  f = Dir.glob(File.join(root, "{README,readme,Readme}*")).first
  return nil unless f
  File.read(f, 4000, encoding: "UTF-8").scrub
rescue
  nil
end

def deprecation_text(root)
  hits = []
  Dir.glob(File.join(root, "{README,readme,Readme}*")).first(1).each do |f|
    File.foreach(f).first(200).each do |line|
      hits << line.strip if line =~ DEPRECATION_RE
    end
  end
  Dir.glob(File.join(root, "{*.gemspec,package.json,setup.py,pyproject.toml,Cargo.toml,composer.json}")).each do |f|
    File.foreach(f) { |line| hits << line.strip if line =~ DEPRECATION_RE }
  end
  hits.empty? ? nil : hits.uniq.join(" | ")[0, 500]
rescue
  nil
end

def measure(url, ecosystems)
  cache = File.join(CACHE, "#{hkey(url)}.json")
  if File.exist?(cache)
    body = File.read(cache)
    return body == "null" ? nil : JSON.parse(body)
  end

  result = nil
  Dir.mktmpdir("bernies-size-") do |dir|
    unless clone(url, dir)
      File.write(cache, "null")
      return nil
    end

    brief_out = run("brief", "--json", dir) || run("brief", dir)
    brief_json = brief_out ? (JSON.parse(brief_out) rescue nil) : nil
    File.write(File.join(BRIEF, "#{hkey(url)}.json"), brief_out) if brief_out

    src = source_dir(dir, ecosystems)
    scc_out = run("scc", "--no-cocomo", "--format", "json", src)
    scc = scc_out ? (JSON.parse(scc_out) rescue []) : []

    code_loc   = scc.sum { |l| l["Code"] || 0 }
    comment    = scc.sum { |l| l["Comment"] || 0 }
    files      = scc.sum { |l| l["Count"] || 0 }
    complexity = scc.sum { |l| l["Complexity"] || 0 }
    langs      = scc.to_h { |l| [l["Name"], l["Code"]] }
    has_native = scc.any? { |l| NATIVE_LANGS.include?(l["Name"]) } ? 1 : 0
    has_native = 1 if brief_json && (brief_json["languages"] || []).any? { |l| NATIVE_LANGS.include?(l["name"]) }

    result = {
      "code_loc"         => code_loc,
      "comment_loc"      => comment,
      "code_files"       => files,
      "complexity"       => complexity,
      "entry_points"     => entry_points(dir, src, ecosystems),
      "languages"        => langs,
      "has_native"       => has_native,
      "deprecation_text" => deprecation_text(dir),
      "readme"           => readme_excerpt(dir),
      "src_relative"     => (src == dir ? "." : src.delete_prefix(dir + "/")),
    }
    FileUtils.rm_rf(File.join(dir, ".git")) if KEEP
  end

  File.write(cache, JSON.generate(result))
  result
rescue => e
  warn "  #{url}: #{e.class}: #{e.message}"
  nil
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true
{
  code_loc: "INTEGER", comment_loc: "INTEGER", code_files: "INTEGER",
  complexity: "INTEGER", entry_points: "INTEGER", languages: "TEXT",
  has_native: "INTEGER", deprecation_text: "TEXT", size_synced_at: "TEXT"
}.each do |c, t|
  db.execute("ALTER TABLE repos ADD COLUMN #{c} #{t}") rescue SQLite3::SQLException
end

eco_filter    = ECO ? "AND p.ecosystem = '#{ECO}'" : ""
bucket_filter = if BUCKET then "AND r.bucket = '#{BUCKET}'"
                elsif ALL then ""
                else "AND (r.bucket IS NULL OR r.bucket <> 'active')"
                end
rows = db.execute(<<~SQL)
  SELECT r.repository_url,
         GROUP_CONCAT(DISTINCT p.ecosystem) AS ecosystems
  FROM repos r JOIN packages p ON p.repository_url = r.repository_url
  WHERE r.size_synced_at IS NULL
    AND r.host IN (#{CLONE_HOSTS.map { |h| "'#{h}'" }.join(",")})
    #{bucket_filter}
    #{eco_filter}
  GROUP BY r.repository_url
  ORDER BY (r.bucket IN ('dead','dormant')) DESC, r.repository_url
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{rows.size} repos to size"

upd = db.prepare <<~SQL
  UPDATE repos SET code_loc=?, comment_loc=?, code_files=?, complexity=?,
    entry_points=?, languages=?, has_native=?, deprecation_text=?, size_synced_at=?
  WHERE repository_url=?
SQL

now = Time.now.utc.iso8601
hit = miss = 0
rows.each_with_index do |r, i|
  url = r["repository_url"]
  ecos = (r["ecosystems"] || "").split(",")
  m = measure(url, ecos)
  if m
    upd.execute(
      m["code_loc"], m["comment_loc"], m["code_files"], m["complexity"],
      m["entry_points"], JSON.generate(m["languages"]), m["has_native"],
      m["deprecation_text"], now, url
    )
    hit += 1
  else
    upd.execute(nil, nil, nil, nil, nil, nil, nil, nil, now, url)
    miss += 1
  end
  print "\r[#{i + 1}/#{rows.size}] hit=#{hit} miss=#{miss}"
end
upd.close
puts
puts "sized #{hit}, failed #{miss}"
