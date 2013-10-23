include_attribute "smartstack::services"
include_attribute "smartstack::ports"
include_attribute "smartstack::nerve"
include_attribute "smartstack::synapse"

# attributes loaded only during testing
if node.smartstack.env == 'test'
  default.nerve.enabled_services << 'helloworld'
  default.synapse.enabled_services << 'helloworld'

  default.smartstack.helloworld.port = 9494

  default.smartstack.zk_version = '3.4.5'
  default.smartstack.zk_home = '/srv/zookeeper'
  default.zookeeper.smartstack_cluster = ['localhost:2181', 'localhost:3181', 'localhost:4181']
end
