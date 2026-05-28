#!/usr/bin/env ruby
# LLM pre-fill of situation/remediation for non-active packages where the
# heuristics in situate.rb left gaps or need a second opinion. Shells out
# to `claude -p` with a JSON schema so the response is structured. Raw
# responses cached under cache/llm so prompt iteration is free.
#
# Treat output as a better pre-fill, not ground truth. tag.rb confirms.
#
# Usage: ruby llm.rb [LIMIT] [--all] [--force]

require "json"
require "sqlite3"
require "fileutils"
require "digest"
require "open3"
require "time"
require "thread"

WORKDIR = __dir__
DB_PATH = File.join(WORKDIR, "bernies.db")
CACHE   = File.join(WORKDIR, "cache", "llm")
SIZE    = File.join(WORKDIR, "cache", "size")
BRIEF   = File.join(WORKDIR, "cache", "brief")
LIMIT   = ARGV.grep(/\A\d+\z/).first&.to_i
ALL     = ARGV.include?("--all")
FORCE   = ARGV.include?("--force")
ECO     = (i = ARGV.index("--ecosystem")) && ARGV[i + 1]
BUCKET  = (i = ARGV.index("--bucket")) && ARGV[i + 1]
MODEL   = ENV["BERNIES_MODEL"] || "haiku"
WORKERS = (ENV["BERNIES_WORKERS"] || 4).to_i

PROMPT_VERSION = 1

FileUtils.mkdir_p(CACHE)

SITUATIONS = %w[few-large broad inlineable alternative kitchen-sink no-alternative]
REMEDIATIONS = %w[adopt vendor switch switch-piecemeal accept]

SCHEMA = {
  type: "object",
  properties: {
    situation:        { enum: SITUATIONS },
    eol_direct:       { type: "boolean" },
    remediation:      { enum: REMEDIATIONS },
    alternative_purl: { type: ["string", "null"] },
    note:             { type: "string", maxLength: 300 },
    confidence:       { type: "number", minimum: 0, maximum: 1 },
  },
  required: %w[situation remediation note confidence],
  additionalProperties: false,
}.freeze

TAXONOMY = <<~TXT
  situation:
    few-large      a handful of large dependents account for most usage
    broad          many small dependents, no obvious steward
    inlineable     small enough to copy into the consuming project
    alternative    a maintained drop-in replacement exists
    kitchen-sink   large surface, dependents use a slice, multiple replacements needed
    no-alternative fills a niche nothing else covers, often native/protocol code
  remediation:
    adopt            fork or take over maintenance
    vendor           copy the code in, drop the dependency
    switch           replace wholesale with one alternative
    switch-piecemeal replace the used slice with several packages
    accept           keep it, pin the version, carry the risk
TXT

def hkey(s) = Digest::SHA256.hexdigest(s)[0, 32]

def load_size(repo_url)
  return {} unless repo_url
  path = File.join(SIZE, "#{hkey(repo_url)}.json")
  return {} unless File.exist?(path)
  JSON.parse(File.read(path)) || {}
rescue
  {}
end

def load_brief(repo_url)
  return nil unless repo_url
  path = File.join(BRIEF, "#{hkey(repo_url)}.json")
  return nil unless File.exist?(path)
  j = JSON.parse(File.read(path)) rescue (return nil)
  {
    "languages"        => (j["languages"] || []).map { |l| l["name"] },
    "package_managers" => (j["package_managers"] || []).map { |pm| pm["name"] },
    "tools"            => (j["tools"] || {}).transform_values { |a| a.map { |t| t["name"] } },
    "dependencies"     => (j["dependencies"] || []).map { |d| d["name"] }.first(20),
    "lines"            => j["lines"],
  }
end

def build_prompt(p, deps, size, brief)
  ctx = {
    purl:       p["purl"],
    name:       p["name"],
    ecosystem:  p["ecosystem"],
    description: p["description"],
    bucket:     p["bucket"],
    signals:    p["signals"],
    dependent_packages: p["dependent_packages"],
    dependent_repos:    p["dependent_repos"],
    runtime_deps:       p["runtime_deps"],
    dead_transitive_count: p["dead_transitive_count"],
    code_loc:    p["code_loc"],
    code_files:  p["code_files"],
    complexity:  p["complexity"],
    entry_points: p["entry_points"],
    has_native:   p["has_native"] == 1,
    archived:     p["archived"] == 1,
    deprecation_text: p["deprecation_text"],
    heuristic_situation: p["situation"],
    top1_share:  p["top1_share"]&.round(3),
    top_dependents: deps,
    brief: brief,
  }.compact

  <<~PROMPT
    You are classifying an unmaintained open-source package to advise dependents what to do about it.

    Taxonomy:
    #{TAXONOMY}

    Package context (JSON):
    #{JSON.pretty_generate(ctx)}

    README excerpt:
    #{(size["readme"] || "(none)")[0, 2000]}

    Pick exactly one situation and one remediation. If you name an alternative,
    give its purl (pkg:<ecosystem>/<name>) and only if you are confident it is
    actively maintained; otherwise null. The note is one or two sentences a
    developer would read. confidence is 0..1.
  PROMPT
end

def ask(prompt, cache_key)
  path = File.join(CACHE, "#{cache_key}.json")
  if File.exist?(path) && !FORCE
    body = File.read(path)
    return body == "null" ? nil : JSON.parse(body)
  end

  cmd = [
    "claude", "-p",
    "--model", MODEL,
    "--output-format", "json",
    "--json-schema", JSON.generate(SCHEMA),
    "--no-session-persistence",
  ]
  out, err, st = Open3.capture3(*cmd, stdin_data: prompt)
  unless st.success?
    warn "  claude -p failed: #{err.strip}"
    return nil
  end

  wrapper = JSON.parse(out)
  if wrapper["is_error"]
    warn "  claude error: #{wrapper['result']}"
    return nil
  end
  parsed = wrapper["structured_output"]
  File.write(path, JSON.generate(parsed.merge("_cost_usd" => wrapper["total_cost_usd"])))
  parsed
rescue JSON::ParserError => e
  warn "  parse error: #{e.message}"
  nil
end

db = SQLite3::Database.new(DB_PATH)
db.busy_timeout = 5000
db.results_as_hash = true

bucket_filter = if BUCKET then "AND r.bucket = '#{BUCKET}'"
                elsif ALL then ""
                else "AND r.bucket IN ('dead','dormant','unknown')"
                end
eco_filter    = ECO ? "AND p.ecosystem = '#{ECO}'" : ""
rows = db.execute(<<~SQL)
  SELECT p.purl, p.name, p.ecosystem, p.repository_url,
         p.dependent_packages, p.dependent_repos, p.runtime_deps,
         p.dead_transitive_count, p.top1_share, p.situation,
         r.bucket, r.signals, r.code_loc, r.code_files, r.complexity,
         r.entry_points, r.has_native, r.archived, r.deprecation_text
  FROM packages p LEFT JOIN repos r ON r.repository_url = p.repository_url
  WHERE p.tagged_at IS NULL #{bucket_filter} #{eco_filter}
  ORDER BY p.dependent_repos DESC
  #{"LIMIT #{LIMIT}" if LIMIT}
SQL

puts "#{rows.size} packages to classify via claude -p (model=#{MODEL})"

dep_stmt = db.prepare("SELECT dependent_name, dependent_downloads, description FROM dependents WHERE purl=? ORDER BY rank LIMIT 5")
upd = db.prepare <<~SQL
  UPDATE packages SET
    situation=?, eol_direct=COALESCE(?, eol_direct), remediation=?,
    alternative_purl=?, remediation_notes=?, llm_confidence=?,
    remediation_source='llm'
  WHERE purl=? AND (remediation_source IS NULL OR remediation_source <> 'human')
SQL

deps_for = {}
rows.each do |p|
  deps_for[p["purl"]] = dep_stmt.execute(p["purl"]).map { |d|
    { name: d["dependent_name"], downloads: d["dependent_downloads"], description: d["description"] }
  }
end
dep_stmt.close

queue = Queue.new
rows.each { |p| queue << p }
done = Queue.new

threads = WORKERS.times.map do
  Thread.new do
    while (p = queue.pop(true) rescue nil)
      size   = load_size(p["repository_url"])
      brief  = load_brief(p["repository_url"])
      prompt = build_prompt(p, deps_for[p["purl"]], size, brief)
      key    = hkey("v#{PROMPT_VERSION}|#{p['purl']}")
      done << [p["purl"], ask(prompt, key)]
    end
  end
end

hit = miss = processed = 0
until processed == rows.size
  purl, r = done.pop
  if r
    upd.execute(
      r["situation"], r["eol_direct"].nil? ? nil : (r["eol_direct"] ? 1 : 0),
      r["remediation"], r["alternative_purl"], r["note"], r["confidence"],
      purl
    )
    hit += 1
  else
    miss += 1
  end
  processed += 1
  print "\r[#{processed}/#{rows.size}] hit=#{hit} miss=#{miss}"
end
threads.each(&:join)
upd.close
puts
puts "classified #{hit}, failed #{miss}"
