# set up common stuff first
include_recipe 'smartstack::default'

# set up nerve
directory node.nerve.home do
  owner     node.smartstack.user
  group     node.smartstack.user
  recursive true
end

if node.nerve.jarname
  include_recipe 'java'

  url = "#{node.smartstack.jar_source}/nerve/#{node.nerve.jarname}"
  remote_file File.join(node.nerve.home, node.nerve.jarname) do
    source url
    mode   00644
  end
else
  git node.nerve.install_dir do
    user              node.smartstack.user
    group             node.smartstack.user
    repository        node.nerve.repository
    reference         node.nerve.reference
    enable_submodules true
    action     :sync
    notifies   :run, 'execute[nerve_install]', :immediately
    notifies   :restart, 'runit_service[nerve]'
  end

  # do the actual install of nerve and dependencies
  execute "nerve_install" do
    cwd     node.nerve.install_dir
    user    node.smartstack.user
    group   node.smartstack.user
    action  :nothing

    environment ({'GEM_HOME' => node.smartstack.gem_home})
    command     "bundle install --without development"
  end
end

# add all checks from all the enabled services
# we do this in the recipe to avoid wierdness with attribute load order
node.nerve.enabled_services.each do |service_name|
  unless node.smartstack.services.include? service_name
    Chef::Log.warn "[nerve] skipping non-existent service #{service_name}"
    next
  end

  service = node.smartstack.services[service_name].deep_to_hash

  unless service.include? 'nerve'
    Chef::Log.warn "[nerve] skipping unconfigured service #{service_name}"
    next
  end

  check = service['nerve']
  check['zk_hosts'] = node.zookeeper.smartstack_cluster
  check['zk_path'] = service['zk_path']
  check['host'] = node.ipaddress

  # support multiple copies of the service on one machine with multiple ports in services
  check['ports'] ||= []
  check['ports'] << check['port'] if check['port']
  Chef::Log.warn "[nerve] service #{service_name} has no check ports configured" if check['ports'].empty?

  # add the checks to the nerve config
  check['ports'].each do |port|
    check['port'] = port
    node.default.nerve.config.services["#{service_name}_#{port}"] = check
  end
end

# write the config to the config file for nerve
file node.nerve.config_file do
  user    node.smartstack.user
  group   node.smartstack.user
  content JSON::pretty_generate(node.nerve.config.deep_to_hash)
  notifies :restart, 'runit_service[nerve]'
end

# set up runit service
# we don't want a converge to randomly start nerve if someone is debugging
# so, we only enable nerve; setting it up initially causes it to start,
runit_service 'nerve' do
  action :enable
  default_logger true
end
