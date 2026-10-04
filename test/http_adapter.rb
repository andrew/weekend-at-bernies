require "faraday"
require "json"

class ScriptHttpAdapter < Faraday::Adapter::Test
  STUBS = Faraday::Adapter::Test::Stubs.new do |stub|
    JSON.parse(File.read(ENV.fetch("HTTP_STUBS"))).each do |method, url, status, headers, body|
      stub.public_send(method, url) do
        raise Faraday::TimeoutError, body if status == "timeout"

        [status, headers, body]
      end
    end
  end

  def initialize(app, *)
    super(app, STUBS)
  end
end

Faraday.default_adapter = ScriptHttpAdapter
at_exit { ScriptHttpAdapter::STUBS.verify_stubbed_calls }
