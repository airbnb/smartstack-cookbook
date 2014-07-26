include_attribute "smartstack::default"

default.nerve.home = File.join(node.smartstack.home, 'nerve')
default.nerve.install_dir = File.join(node.nerve.home,'src')
default.nerve.config_file = File.join(node.nerve.home,'config.json')

default.nerve.repository = 'https://github.com/airbnb/nerve.git'
default.nerve.reference = 'v0.5.3'
default.nerve.jarname = nil
default.nerve.jvmopts = '-Xmx64m -XX:PermSize=64m'

# a list of keys from node.smartstack.services (services cookbook)
default.nerve.enabled_services = []

default.nerve.local.host = "127.0.0.1"
default.nerve.local.port = 1025

# Cookbook in which the runit_service LWRP will look for an sv-nerve-run.erb
# template:
default.nerve.runit_cookbook = 'smartstack'

# everything below is used to configure nerve at runtime
instance_id = node.hostname
instance_id = node.ec2.instance_id if node.has_key? 'ec2'
default.nerve.config = {
  'instance_id' => instance_id,
  'listen_port' => node.nerve.local.port,
  'services' => {},
}
