include_attribute "smartstack::default"

default.synapse.home = File.join(node.smartstack.home, 'synapse')
default.synapse.install_dir = File.join(node.synapse.home,'src')
default.synapse.config_file = File.join(node.synapse.home,'config.json')

default.synapse.repository = 'https://github.com/airbnb/synapse.git'
default.synapse.reference = 'v0.7.0'
default.synapse.jarname = nil
default.synapse.jvmopts = '-Xmx64m -XX:PermSize=64m'

# override this in your role file or wrapper cookbook
default.synapse.enabled_services = []

default.synapse.haproxy.sock_dir = '/var/haproxy'
default.synapse.haproxy.sock_file = File.join(node.synapse.haproxy.sock_dir, 'stats.sock')
default.synapse.haproxy.channel = 'local1'

default.synapse.config = {
  'services' => {},
  'haproxy' => {
    'reload_command' => "sudo service haproxy reload",
    'config_file_path' =>  '/etc/haproxy/haproxy.cfg',
    'socket_file_path' => node.synapse.haproxy.sock_file,
    'do_writes' => true,
    'do_reloads'=> true,
    'do_socket' => true,
    'global' => [
      'daemon',
      'spread-checks 2',
      'user    haproxy',
      'group   haproxy',
      'maxconn 8192',
      "log     127.0.0.1 #{node.synapse.haproxy.channel}",
      "stats   socket #{node.synapse.haproxy.sock_file} group #{node.smartstack.user} mode 660 level admin",
    ],
    'defaults' => [
      # we log all services by default
      # services that are too high-volume should get an
      #     option dontlog-normal
      # to avoid logging normal successful connections
      'log      global',
      'option   dontlognull',
      'option   log-separate-errors',

      # default timeouts; these should be overriden per service
      'maxconn  2000',
      'timeout  connect 5s',
      'timeout  check   5s',
      'timeout  client  50s',
      'timeout  server  50s',

      # we re-try the request if a backend dies mid-connection
      'option   redispatch',
      'retries  3',

      # default sane balancing between backends
      'balance  roundrobin',
    ],
    'extra_sections' => {
      'listen stats :3212' => [
        'mode http',
        'stats enable',
        'stats uri /',
      ],
    },
  }
}

# add localhost aliases for each enabled service
# at airbnb, this is handled by our infrastructure common cookbook,
# which owns generating /etc/hosts from a template
node.synapse.enabled_services.each do |service_name|
  default.common.localhost_aliases << "#{service_name}.synapse"
end
