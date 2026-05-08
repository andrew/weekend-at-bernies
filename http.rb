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

# GET with on-disk cache. 5xx after retries returns nil and is NOT cached.
def cached_get(connection, path, params, cache_dir)
  key  = Digest::SHA256.hexdigest([connection.url_prefix.to_s, path, params.sort].join("|"))[0, 32]
  file = File.join(cache_dir, "#{key}.json")
  if File.exist?(file)
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
