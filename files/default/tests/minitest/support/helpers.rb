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
  end
end
