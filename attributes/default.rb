include_attribute 'smartstack::ports'
include_attribute 'smartstack::services'

default.smartstack.user = 'smartstack'
default.smartstack.home = '/opt/smartstack'
default.smartstack.gem_home = File.join(node.smartstack.home, '.gem')
default.smartstack.jar_source = "https://airbnb-public.s3.amazonaws.com/smartstack"

# you should override this in your environment with the real cluster
default.zookeeper.smartstack_cluster = [ 'localhost:2181' ]
