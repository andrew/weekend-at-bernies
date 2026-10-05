require_relative "collector_adapter"

module IsolationCommands
  def capture3(*args, **options)
    command = args.first.is_a?(Hash) ? args.drop(1) : args
    if command.first == "claude"
      fixtures = JSON.parse(File.read(ENV.fetch("COLLECTOR_STUBS")))
      expected = fixtures.fetch("prompt_contains")
      raise "missing prompt context: #{expected}" unless options.fetch(:stdin_data).include?(expected)

      File.open(ENV.fetch("COMMAND_LOG"), "a") { |file| file.puts JSON.generate(command) }
      return [JSON.generate("structured_output" => fixtures.fetch("llm")), "", CollectorCommands::Status.new(0)]
    end
    if command.first.end_with?("/whois")
      return super("whois", *command.drop(1), **options)
    end
    super
  end
end

Open3.singleton_class.prepend(IsolationCommands)

module IsolationExecutables
  def executable?(path)
    return true if path == "/opt/homebrew/opt/whois/bin/whois"

    super
  end
end

File.singleton_class.prepend(IsolationExecutables)
