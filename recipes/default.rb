# set up common smartstack stuff
user node.smartstack.user do
  home    node.smartstack.home
  shell   '/sbin/nologin'
  system  true
end

directory node.smartstack.home do
  owner     node.smartstack.user
  group     node.smartstack.user
  recursive true
end

# we need git to install smartstack
package 'git'

# we use runit to set up the services
include_recipe 'runit'

# we're going to need ruby too!
include_recipe 'ruby'
gem_package 'bundler'

# clean up old crap
# TODO: remove eventually
%w{/opt/nerve /opt/synapse}.each do |old_dir|
  directory old_dir do
    action :delete
    recursive true
  end
end
