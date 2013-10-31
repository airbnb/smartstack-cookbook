require 'minitest/spec'
require 'minitest-spec-context'
require 'net/http'

require File.expand_path('../support/helpers', __FILE__)

describe_recipe 'smartstack::test' do
  include Helpers::SmartStack

  let(:synapse_config) { JSON.parse(File.open(node.synapse.config_file).read()) }
  let(:nerve_config) { JSON.parse(File.open(node.nerve.config_file).read()) }

  describe 'service creation' do
    parallelize_me!

    it 'starts nerve' do
      service('nerve').must_be_running
    end

    it 'starts synapse' do
      service('synapse').must_be_running
    end

    it 'starts the helloworld service' do
      service('helloworld').must_be_running
    end

    it 'starts 3 zookeeper boxes' do
      service('zookeeper0').must_be_running
      service('zookeeper1').must_be_running
      service('zookeeper2').must_be_running
    end
  end

  describe 'nerve' do
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

    it 'includes a helloworld section in nerve config' do
      nerve_config.must_include 'services'
      nerve_config['services'].must_include 'helloworld'
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

    let(:port) { node.smartstack.helloworld.port }

    it 'responds to /health' do
      response = Net::HTTP.get_response('localhost', '/health', port)
      response.must_be_kind_of Net::HTTPOK
    end

    it 'responds to /ping' do
      response = Net::HTTP.get_response('localhost', '/ping', port)
      response.must_be_kind_of Net::HTTPOK
    end
  end

  describe 'proper discovery' do
    let(:zk_node) {
      registration_path = nerve_config['services']['helloworld']['zk_path']
      registration_node = nerve_config['instance_id'] + '_helloworld'
      "#{registration_path}/#{registration_node}"
    }

    context 'when the service is up' do
      it 'is properly registered in zookeeper' do
        service = nerve_config['services']['helloworld']

        output = zk_cli("get #{zk_node}")

        output.stderr.wont_include "Node does not exist"
        output.stdout.must_include service['host']
        output.stdout.must_include service['port'].to_s
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
        shell_out("sv down helloworld")
        sleep 4
      end

      after do
        shell_out("sv up helloworld")
        sleep 2
      end

      it 'is unavailable in zookeeper' do
        output = zk_cli("get #{zk_node}")
        output.stderr.must_include "Node does not exist"
      end

      it 'is unreachable via synapse' do
        synapse_port = synapse_config['services']['helloworld']['haproxy']['port']

        response = Net::HTTP.get_response('localhost', '/health', synapse_port)
        response.must_be_kind_of Net::HTTPServiceUnavailable
      end
    end

    context 'when the service has been restarted' do
      before do
        shell_out('sv down helloworld')
        sleep 4
        shell_out('sv up helloworld')
        sleep 2
      end

      it 'is again available in zookeeper' do
        output = zk_cli("get #{zk_node}")
        output.stderr.wont_include "Node does not exist"
      end
    end
  end

  describe 'synapse haproxy handling' do
    it %{doesn't restart haproxy when removing a service}
    it %{doesn't restart haproxy when removing and then adding a service}
    it %{restarts haproxy when adding a service for the first time}
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
