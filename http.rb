$stdout.sync = true

require "faraday"
require "faraday/retry"
require "faraday/follow_redirects"
require "json"
require "digest"
require "fileutils"

UA = "weekend-at-bernies (andrew@ecosyste.ms)"

module Bernies
  HttpResult = Struct.new(:data, :status, :reason, :url, :host_status, :resolved_url, keyword_init: true)
end

def http_failure_reason(status)
  case status
  when 404 then "not_found"
  when 401, 403 then "access_denied"
  when 408 then "timeout"
  when 429 then "rate_limited"
  when 500..599 then "server_error"
  else "http_error"
  end
end

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

def github_repository_response(repo_url, cache_dir, refresh: false)
  github_repo = %r{\Ahttps://github\.com/[^/?#]+/[^/?#]+/?\z}i
  return nil unless repo_url.match?(github_repo)

  key = Digest::SHA256.hexdigest(repo_url)[0, 32]
  file = File.join(cache_dir, "redirect-#{key}.json")
  if !refresh && File.exist?(file)
    destination = JSON.parse(File.read(file))
    return Bernies::HttpResult.new(data: destination, url: destination)
  end

  res = conn("https://github.com").head(repo_url)
  result = Bernies::HttpResult.new(status: res.status, url: res.env.url.to_s)
  unless res.success?
    result.reason = http_failure_reason(res.status)
    return result
  end

  redirected_url = res.env.url.to_s
  unless redirected_url.match?(github_repo)
    result.reason = "invalid_redirect"
    return result
  end

  File.write(file, JSON.generate(redirected_url)) if redirected_url != repo_url
  result.data = redirected_url
  result
rescue Faraday::Error => e
  Bernies::HttpResult.new(url: repo_url, reason: e.is_a?(Faraday::TimeoutError) ? "timeout" : "network_error")
end

def cached_get(connection, path, params, cache_dir, refresh: false)
  cached_response(connection, path, params, cache_dir, refresh: refresh).data
end

def cached_response(connection, path, params, cache_dir, refresh: false)
  url = connection.build_url(path, params).to_s
  key  = Digest::SHA256.hexdigest([connection.url_prefix.to_s, path, params.sort].join("|"))[0, 32]
  file = File.join(cache_dir, "#{key}.json")
  if !refresh && File.exist?(file)
    begin
      data = JSON.parse(File.read(file))
    rescue JSON::ParserError
      data = nil
    end
    return Bernies::HttpResult.new(data: data, url: url) unless data.nil?
  end

  res = connection.get(path, params)
  sleep 0.1
  result = Bernies::HttpResult.new(status: res.status, url: url)
  unless res.success?
    File.delete(file) if File.exist?(file)
    result.reason = http_failure_reason(res.status)
    return result
  end
  result.data = JSON.parse(res.body)
  if result.data.nil?
    File.delete(file) if File.exist?(file)
    result.reason = "empty_response"
  else
    File.write(file, res.body)
  end
  result
rescue JSON::ParserError
  File.delete(file) if File.exist?(file)
  Bernies::HttpResult.new(status: res.status, url: url, reason: "invalid_json")
rescue Faraday::Error => e
  File.delete(file) if File.exist?(file)
  warn "  #{path} #{params.inspect}: #{e.class}: #{e.message}"
  Bernies::HttpResult.new(url: url, reason: e.is_a?(Faraday::TimeoutError) ? "timeout" : "network_error")
end
