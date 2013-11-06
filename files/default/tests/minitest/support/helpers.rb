require 'net/http'

module Helpers
  module SmartStack
    include MiniTest::Chef::Assertions
    include MiniTest::Chef::Context
    include MiniTest::Chef::Resources

    # supports the shell_out function
    require 'chef/mixin/shell_out'
    include Chef::Mixin::ShellOut

    # for querying zookeeper
    def zk_cli(command)
      script = File.join(
        node.smartstack.zk_home,
        "zookeeper-#{node.smartstack.zk_version}",
        'bin/zkCli.sh')
      shell_out("#{script} #{command}")
    end

    def http_take_down(service, max_wait = 10, sleep_time = 0.2)
      port = node.smartstack[service].port
      shell_out("sv down #{service}")

      success = false
      start = Time.now()
      while (Time.now() - max_wait) < start
        begin
          response = Net::HTTP.get_response('localhost', '/health', port)
        rescue Errno::ECONNREFUSED
          success = true
          break
        rescue StandardError
          # other errors are ignored
        else
          sleep sleep_time
        end
      end

      raise StandardError, "service #{service} never went down" unless success
    end

    def http_bring_up(service, max_wait = 10, sleep_time = 0.2)
      port = node.smartstack[service].port
      shell_out("sv up #{service}")

      success = false
      start = Time.now()
      while (Time.now() - max_wait) < start
        begin
          response = Net::HTTP.get_response('localhost', '/health', port)
        rescue
          # nothing
        end

        if response.kind_of? Net::HTTPOK
          success = true
          break
        end

        sleep sleep_time
      end

      raise StandardError, "service #{service} never came up" unless success
    end
  end
end
