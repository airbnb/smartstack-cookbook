# uninstall synapse

# disable runit service
include_recipe 'runit'
runit_service "synapse" do
  action :disable
end

# clean up haproxy
package 'haproxy' do
  action :remove
end

file '/etc/defaults/haproxy' do
  action :delete
end

directory node.synapse.haproxy.sock_dir do
  action    :delete
  recursive true
end

# remove synapse home
directory node.synapse.home do
  action    :delete
  recursive true
end
