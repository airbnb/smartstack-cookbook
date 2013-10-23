default.smartstack.ports = {
  # reserved for health checks on synapse itself
  # TODO: implement health checks on synapse
  3210 => 'synapse',
  # reserved for a possible UI for nerve
  3211 => 'nerve',
  # reserved for the haproxy stats socket
  3212 => 'haproxy',

  # moar services
  3333 => 'helloworld',
}

# also create a mapping going the other way
default.smartstack.service_ports = Hash[node.smartstack.ports.collect {|k, v| [v, k]}]
