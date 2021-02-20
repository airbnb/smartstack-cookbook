include_attribute 'smartstack::ports'
include_attribute 'smartstack::services'

default.smartstack.user = 'smartstack'
default.smartstack.home = '/opt/smartstack'
default.smartstack.gem_home = File.join(node.smartstack.home, '.gem')
default.smartstack.jar_source = nil

# you should override this in your environment with the real cluster
default.zookeeper.smartstack_cluster = [ 'localhost:2181' ]

default.smartstack.service_path = value_for_platform(
  'centos' => { 'default' => '/sbin/service' },
  'ubuntu' => { 'default' => '/usr/sbin/service' },
  'default' => '/usr/sbin/service'
)
