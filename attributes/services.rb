include_attribute 'smartstack::ports'

default.smartstack.services = {
  'synapse' => {},
  'nerve'   => {},
  'haproxy' => {},

  'helloworld' => {
    'synapse' => {
      'discovery' => { 'method' => 'zookeeper' },
      'haproxy' => {
        'server_options' => 'check inter 1s rise 1 fall 1',
        'listen' => [
          'mode http',
          'option httpchk GET /ping',
        ],
      },
    },
    'nerve' => {
      'port' => 9494,
      'check_interval' => 1,
      'checks' => [
        { 'type' => 'http', 'uri' => '/health', 'timeout' => 1, 'rise' => 1, 'fall' => 2 },
      ],
    },
  },
}

# on chef-solo < 11.6, we hack around lack of environment support
# by using node.env because node.environment cannot be set
default.smartstack.env = (node.has_key?('env') ? node.env : node.environment)

# make sure each service has a smartstack config
default.smartstack.services.each do |name, service|
  # populate zk paths for all services
  unless service.has_key? 'zk_path'
    default.smartstack.services[name]['zk_path'] = "/#{node.smartstack.env}/services/#{name}/services"
  end

  # populate the local_port for all services
  port = node.smartstack.service_ports[name]
  if Integer === port
    service['local_port'] = port
  else
    Chef::Log.error "Service #{name} has no synapse port allocated; please see services/attributes/ports.rb"
    raise "Synapse port missing for #{name}"
  end
end
