include_attribute "smartstack::services"
include_attribute "smartstack::ports"
include_attribute "smartstack::nerve"
include_attribute "smartstack::synapse"

# attributes loaded only during testing
if node.smartstack.env == 'test'
  # which ports to run helloworld on?
  ports = [9494, 9495]
  default.smartstack.helloworld.ports = ports
  default.smartstack.services.helloworld.nerve.ports = ports

  # enable helloworld
  default.nerve.enabled_services << 'helloworld'
  default.synapse.enabled_services << 'helloworld'

  # zk settings
  default.smartstack.zk_version = '3.4.5'
  default.smartstack.zk_home = '/srv/zookeeper'
  default.zookeeper.smartstack_cluster = ['localhost:2181', 'localhost:3181', 'localhost:4181']
end
