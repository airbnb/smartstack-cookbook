# -*- mode: ruby -*-
# vi: set ft=ruby :

# this is going to be necessary with chef 11.6 environment support
#smartstack_dir = File.dirname(File.expand_path __FILE__)

Vagrant.configure("2") do |master_config|

  # Enabling the Berkshelf plugin. To enable this globally, add this configuration
  # option to your ~/.vagrant.d/Vagrantfile file
  master_config.berkshelf.enabled = true

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to exclusively install and copy to Vagrant's shelf.
  # master_config.berkshelf.only = []

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to skip installing and copying to Vagrant's shelf.
  # master_config.berkshelf.except = []

  master_config.vm.define "smartstack" do |config|
    config.vm.box     = "smartstack"
    config.vm.box_url = "https://airbnb-public.s3.amazonaws.com/vagrant-boxes/ubuntu12.04-chef11.4.4-vbox4210.box"

    config.vm.network :private_network, ip: '172.16.1.3'

    config.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id,
        '--memory', '512',
        '--cpus',   '2',
      ]
    end

    config.vm.provision :chef_solo do |chef|
      chef.json = {
        :smartstack => {
          :development => true
        },
        :env => 'test',
        :languages => { :ruby => { :default_version => '1.9.1' } },
      }

      # uncomment to use with chef 11.6
      #chef.environments_path = File.join(smartstack_dir, 'environments')
      #chef.environment = 'test'

      chef.run_list = [
          "recipe[apt]",
          "recipe[smartstack::synapse]",
          "recipe[smartstack::nerve]",
          "recipe[smartstack::test]",
          "recipe[minitest-handler]"
      ]
    end
  end
end
