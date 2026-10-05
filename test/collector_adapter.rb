require_relative "http_adapter"
require "open3"
require "resolv"
require "fileutils"

module CollectorCommands
  Status = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
  end

  def capture3(*args, **options)
    command = args.first.is_a?(Hash) ? args.drop(1) : args
    fixtures = JSON.parse(File.read(ENV.fetch("COLLECTOR_STUBS")))
    File.open(ENV.fetch("COMMAND_LOG"), "a") { |file| file.puts JSON.generate(command) }
    case command.first
    when "git"
      raise "unexpected git command: #{command.inspect}" unless command.include?("clone")
      return ["", "clone failed", Status.new(1)] if fixtures["clone_failed"]

      directory = command.last
      FileUtils.mkdir_p(File.join(directory, "lib"))
      File.write(File.join(directory, "lib", "example.rb"), "puts 'example'\n")
      ["", "", Status.new(0)]
    when "brief"
      [JSON.generate("languages" => [{ "name" => "Ruby" }]), "", Status.new(0)]
    when "scc"
      return ["", "scc failed", Status.new(1)] if fixtures["scc_failed"]

      [JSON.generate([{ "Name" => "Ruby", "Code" => fixtures.fetch("code_loc"), "Complexity" => 1, "Count" => 1 }]), "", Status.new(0)]
    when "whois"
      [fixtures.fetch("whois", ""), "", Status.new(fixtures["whois_failed"] ? 1 : 0)]
    else
      raise "unexpected command: #{command.inspect}"
    end
  end

  def capture2(*args, **options)
    command = args.first.is_a?(Hash) ? args.drop(1) : args
    raise "unexpected command: #{command.inspect}" unless command.first == "git" && command.include?("log")

    fixtures = JSON.parse(File.read(ENV.fetch("COLLECTOR_STUBS")))
    ["#{fixtures.fetch('last_commit_at')}\t#{'a' * 40}\n", Status.new(0)]
  end
end

Open3.singleton_class.prepend(CollectorCommands)

class CollectorDNS
  attr_accessor :timeouts

  def getresources(domain, type)
    fixtures = JSON.parse(File.read(ENV.fetch("COLLECTOR_STUBS")))
    raise Resolv::ResolvTimeout if fixtures["dns_failed"]

    fixtures.fetch("resolves", true) ? [Object.new] : []
  end
end

class << Resolv::DNS
  def open
    yield CollectorDNS.new
  end
end

module Kernel
  def sleep(*)
  end
end
