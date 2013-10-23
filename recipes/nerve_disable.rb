# uninstall nerve

# disable runit servie
include_recipe 'runit'
runit_service 'nerve' do
  action :disable
end

# remove nerve home
directory node.nerve.home do
  action    :delete
  recursive true
end
