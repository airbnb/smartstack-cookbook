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

# set up keys for pulling private repos
# remove after open-sourcing the repos
keyfile = File.join(node.smartstack.home, "git_key")
cookbook_file "deploy_key" do
  mode     00400
  owner    node.smartstack.user
  group    node.smartstack.user
  path     keyfile
end

file node.smartstack.git_wrapper do
  mode     00500
  owner    node.smartstack.user
  group    node.smartstack.user
  content  "ssh -i #{keyfile} -o StrictHostKeyChecking=no $1 $2"
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
