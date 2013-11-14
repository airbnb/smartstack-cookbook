require 'minitest/spec'
require 'minitest-spec-context'
require 'net/http'

require File.expand_path('../support/helpers', __FILE__)

describe_recipe 'smartstack::test' do
  include Helpers::SmartStack

  let(:synapse_config) { JSON.parse(File.open(node.synapse.config_file).read()) }
  let(:nerve_config) { JSON.parse(File.open(node.nerve.config_file).read()) }
  let(:helloworld_ports) { node.smartstack.helloworld.ports }

  describe 'service creation' do
    parallelize_me!

    it 'starts nerve' do
      service('nerve').must_be_running
    end

    it 'starts synapse' do
      service('synapse').must_be_running
    end

    it 'starts the helloworld services' do
      helloworld_ports.each do |port|
        service("helloworld#{port}").must_be_running
      end
    end

    it 'starts 3 zookeeper boxes' do
      service('zookeeper0').must_be_running
      service('zookeeper1').must_be_running
      service('zookeeper2').must_be_running
    end
  end

  describe 'nerve shutdown handling' do
    it 'restarts cleanly' do
      [0..5].each do |trial|
        down = shell_out!('sv down nerve')
        down.status.exitstatus.must_equal 0

        up = shell_out!('sv up nerve')
        up.status.exitstatus.must_equal 0
      end
    end

    it 'properly handles signals' do
    end
  end

  describe 'proper config' do
    parallelize_me!

    it 'includes helloworld sections in nerve config' do
      nerve_config.must_include 'services'

      helloworld_ports.each do |port|
        nerve_config['services'].must_include "helloworld_#{port}"
      end
    end

    describe 'properly configures synapse for helloworld' do
      it 'includes a helloworld section' do
        synapse_config.must_include 'services'
        synapse_config['services'].must_include 'helloworld'
      end

      it 'uses the proper port' do
        port = synapse_config['services']['helloworld']['haproxy']['port']
        node.smartstack.ports[port].must_equal 'helloworld'
      end
    end
  end

  describe 'helloworld works' do
    parallelize_me!

    let(:ports) { helloworld_ports }

    it 'responds to /health' do
      ports.each do |port|
        response = Net::HTTP.get_response('localhost', '/health', port)
        response.must_be_kind_of Net::HTTPOK
      end
    end

    it 'responds to /ping' do
      ports.each do |port|
        response = Net::HTTP.get_response('localhost', '/ping', port)
        response.must_be_kind_of Net::HTTPOK
      end
    end
  end

  describe 'proper discovery' do
    context 'when the service is up' do
      it 'is properly registered in zookeeper' do
        nerve_config['services'].each do |name, service|
          zk_node = service['zk_path'] + '/' + "#{nerve_config['instance_id']}_#{name}"

          output = zk_cli("get #{zk_node}")

          output.stderr.wont_include "Node does not exist"
          output.stdout.must_include service['host']
          output.stdout.must_include service['port'].to_s
        end
      end

      it 'is available via synapse' do
        synapse_port = synapse_config['services']['helloworld']['haproxy']['port']

        response = Net::HTTP.get_response('localhost', '/health', synapse_port)
        response.must_be_kind_of Net::HTTPOK
      end

      it 'is only available on localhost' do
        synapse_port = synapse_config['services']['helloworld']['haproxy']['port']

        assert_raises(Errno::ECONNREFUSED) {
          Net::HTTP.get_response(node.ipaddress, '/health', synapse_port)
        }
      end
    end

    context 'when the service is down' do
      before do
        @pid = IO.read('/var/run/haproxy.pid')
        stop_all('helloworld', helloworld_ports)
      end

      after do
        start_all('helloworld', helloworld_ports)
      end

      it 'is unavailable in zookeeper' do
        nerve_config['services'].each do |name, service|
          zk_node = service['zk_path'] + '/' + "#{nerve_config['instance_id']}_#{name}"

          output = zk_cli("get #{zk_node}")
          output.stderr.must_include "Node does not exist"
        end
      end

      it 'is unreachable via synapse' do
        synapse_port = synapse_config['services']['helloworld']['haproxy']['port']

        response = Net::HTTP.get_response('localhost', '/health', synapse_port)
        response.must_be_kind_of Net::HTTPServiceUnavailable
      end

      it "hasn't caused haproxy to restart" do
        IO.read('/var/run/haproxy.pid').must_equal @pid
      end
    end

    context 'when the service has been restarted' do
      before do
        stop_all('helloworld', helloworld_ports)
        start_all('helloworld', helloworld_ports)
      end

      it 'is again available in zookeeper' do
        nerve_config['services'].each do |name, service|
          zk_node = service['zk_path'] + '/' + "#{nerve_config['instance_id']}_#{name}"

          output = zk_cli("get #{zk_node}")
          output.stderr.wont_include "Node does not exist"
        end
      end
    end
  end

  describe 'synapse haproxy handling' do
    it %{generates the correct frontend and backend stanzas} do
      haproxy_config = parsed_haproxy_config

      haproxy_config['frontend'].must_include 'helloworld'
      haproxy_config['backend'].must_include 'helloworld'

      haproxy_config['frontend']['helloworld']['config'].must_include 'default_backend helloworld'
      haproxy_config['frontend']['helloworld']['config'].must_include(
        "bind localhost:#{node.smartstack.service_ports['helloworld']}")

      helloworld_ports.each do |port|
        haproxy_config['backend']['helloworld']['config'].to_s.must_match(
          /"server[^"]*#{node.ipaddress}:#{port}/)
      end
    end
  end

  describe 'zookeeper handling' do
    context 'when zookeeper goes down' do
      it 'restarts synapse'
      it 'restarts nerve'
    end

    context 'when a single server in the ensemble is restarted' do
      it 'doesn\'t restart nerve if only a single zk node is down' do
        skip %{this isn't actually true right now}
      end
    end
  end
end
