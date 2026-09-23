require "faraday"
require "json"

class ScriptHttpAdapter < Faraday::Adapter::Test
  STUBS = Faraday::Adapter::Test::Stubs.new do |stub|
    JSON.parse(File.read(ENV.fetch("HTTP_STUBS"))).each do |method, url, status, headers, body|
      stub.public_send(method, url) { [status, headers, body] }
    end
  end

  def initialize(app, *)
    super(app, STUBS)
  end
end

Faraday.default_adapter = ScriptHttpAdapter
at_exit { ScriptHttpAdapter::STUBS.verify_stubbed_calls }
