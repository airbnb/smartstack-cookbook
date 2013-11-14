# set up the hello world service
gem_package 'sinatra'

include_recipe 'runit'
node.smartstack.helloworld.ports.each do |port|
  runit_service "helloworld#{port}" do
    run_template_name  'helloworld'
    action             [:enable, :start]
    default_logger     true

    options({
        :port   => port
      })
  end
end

# set up a zookeeper cluster
include_recipe 'java'
include_recipe 'runit'

user 'zookeeper' do
  action :create
  home   node.smartstack.zk_home
end

directory node.smartstack.zk_home do
  recursive true
  owner     'zookeeper'
  group     'zookeeper'
end

zk_source = "http://mirror.cogentco.com/pub/apache/zookeeper/" +
  "zookeeper-#{node.smartstack.zk_version}/zookeeper-#{node.smartstack.zk_version}.tar.gz "
remote_file File.join(node.smartstack.zk_home, "#{node.smartstack.zk_version}.tar.gz") do
  source zk_source
  owner  'zookeeper'
  group  'zookeeper'
  mode   00644
  action :create_if_missing
end

zk_dir = File.join(node.smartstack.zk_home, "zookeeper-#{node.smartstack.zk_version}")
execute 'extract_zookeeper' do
  cwd     node.smartstack.zk_home
  user    'zookeeper'
  command "tar zxf #{node.smartstack.zk_version}.tar.gz"
  creates zk_dir
end

# set up 3 zookeeper services in a cluster
(0..2).each do |zk_id|
  port = 2181 + zk_id * 1000
  dir = File.join(node.smartstack.zk_home, zk_id.to_s)

  directory File.join(dir, 'data') do
    recursive true
    owner     'zookeeper'
    group     'zookeeper'
    mode      00775
  end

  file File.join(dir, 'data', 'myid') do
    content   zk_id.to_s
    owner     'zookeeper'
    group     'zookeeper'
    mode      00644
  end

  template File.join(dir, 'zookeeper.cfg') do
    owner     'zookeeper'
    group     'zookeeper'
    mode      00644
    notifies :restart, "runit_service[zookeeper#{zk_id}]"
    variables({
      :dir => dir,
      :port => port,
    })
  end

  runit_service "zookeeper#{zk_id}" do
    action [:enable, :start]
    default_logger true
    run_template_name 'zookeeper'

    options({
        :dir => dir
      })
  end
end

# make sure that nerve and synapse are running
runit_service 'nerve' do
  action :start
end

runit_service 'synapse' do
  action :start
end

# we use this in our tests in this cookbook
chef_gem 'minitest-spec-context'
