$stdout.sync = true

require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"
require "json"
require "digest"
require "fileutils"

UA = "weekend-at-bernies (andrew@ecosyste.ms)"

def conn(base)
  Faraday.new(url: base, headers: { "User-Agent" => UA, "Accept" => "application/json" }) do |f|
    f.request :retry,
      max: 4, interval: 1, backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503, 504],
      methods: [:get],
      exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, Faraday::TimeoutError]
    f.response :follow_redirects, limit: 3
    f.options.timeout = 60
    f.options.open_timeout = 10
    f.adapter Faraday.default_adapter
  end
end

def github_repository_redirect(repo_url, cache_dir, refresh: false)
  github_repo = %r{\Ahttps://github\.com/[^/?#]+/[^/?#]+/?\z}i
  return nil unless repo_url.match?(github_repo)

  key = Digest::SHA256.hexdigest(repo_url)[0, 32]
  file = File.join(cache_dir, "redirect-#{key}.json")
  return JSON.parse(File.read(file)) if !refresh && File.exist?(file)

  res = conn("https://github.com").head(repo_url)
  return nil unless res.success?

  redirected_url = res.env.url.to_s
  return nil unless redirected_url.match?(github_repo) && redirected_url != repo_url

  File.write(file, JSON.generate(redirected_url))
  redirected_url
rescue Faraday::Error => e
  warn "  #{repo_url}: #{e.class}: #{e.message}"
  nil
end

# GET with on-disk cache. 5xx after retries returns nil and is NOT cached.
def cached_get(connection, path, params, cache_dir, refresh: false)
  key  = Digest::SHA256.hexdigest([connection.url_prefix.to_s, path, params.sort].join("|"))[0, 32]
  file = File.join(cache_dir, "#{key}.json")
  if !refresh && File.exist?(file)
    body = File.read(file)
    return body == "null" ? nil : JSON.parse(body)
  end

  res = connection.get(path, params)
  sleep 0.1
  unless res.success?
    File.write(file, "null") if res.status < 500
    return nil
  end
  File.write(file, res.body)
  JSON.parse(res.body)
rescue Faraday::Error => e
  warn "  #{path} #{params.inspect}: #{e.class}: #{e.message}"
  nil
end
