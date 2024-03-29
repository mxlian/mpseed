# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Requires an external config file 
CONFIG_FILE_PROD= "../vagrant-prod.rb"
CONFIG_FILE_DEV = "../vagrant-dev.rb"

# Default configs (override in config file only)
PRODUCTION_MODE=true
USE_GUI=false
MAIN_CPU_COUNT=1
MAIN_HOSTNAME="vtfx.dev.mainstorconcept.de"
MAIN_GATEWAY="172.20.1.254"
MAIN_IP_ADDR="192.168.55.50"
MAIN_RAM=1024
EXTRA_MACHINES=0
EXTRA_MACHINES_RAM=756
EXTRA_MACHINES_BASE_IP="192.168.55.5" # Last digit filled by the counter
#PROJECT_NAME="unnamedApp" # Should be overrided un CONFIG_FILE! Should be
#a slug

if File.exist?(CONFIG_FILE_DEV)
    puts "DEVELOPMENT: Loading settings from: #{CONFIG_FILE_DEV}"
    require_relative CONFIG_FILE_DEV
else
    puts "PRODUCTION: Loading setting from (#{CONFIG_FILE_PROD})"
    require_relative CONFIG_FILE_PROD
end
puts "\nPRODUCTION_MODE: #{PRODUCTION_MODE}"
puts "USE_GUI: #{USE_GUI}"

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.provider :virtualbox do |vb| 
        vb.gui = USE_GUI 
        # Use VBoxManage to customize the VM
        vb.customize ["modifyvm", :id, "--memory", EXTRA_MACHINES_RAM]
    end

    config.vm.synced_folder "../", "/repo"

    config.vm.define "main", primary: true do |main|
        main.vm.box = "ubuntu/trusty64"
        main.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
        config.vm.provider :virtualbox do |vb| 
            vb.name = PROJECT_NAME
            vb.customize ["modifyvm", :id, "--memory", MAIN_RAM]
            vb.customize ["modifyvm", :id, "--ioapic", "on"]
            vb.customize ["modifyvm", :id, "--cpus", MAIN_CPU_COUNT]
        end
        main.vm.hostname=MAIN_HOSTNAME

        if PRODUCTION_MODE == true
            # In production mode configure a 'public' ip addres and confugure
            # the fucking gateway when provisioning. Don't forget to provision!
            #
            config.vm.network :public_network, ip: MAIN_IP_ADDR
            default_router = MAIN_GATEWAY
            # change/ensure the default route via the local network's WAN router, 
            # useful for public_network/bridged mode
            config.vm.provision :shell, :inline => "echo 'Network POSCONFIG'; ip route delete default || true; ip route add default via #{default_router}"
        else
            # If not, just use the provided ip address for the private network
            main.vm.network :private_network, ip: MAIN_IP_ADDR
            main.vm.network :forwarded_port, guest: 80, host: 8080
        end

        main.vm.provision :shell, :path => "puppet-install.sh"
        main.vm.provision :shell, :path => "puppet-modules.sh"

        main.vm.provision :puppet do |puppet|
            puppet.manifests_path = "manifests"
            puppet.manifest_file  = "main.pp"
            puppet.facter  = {"projectid" => PROJECT_NAME}
            puppet.options  = "--verbose"
        end
    end 

    (1..EXTRA_MACHINES).each do |i|
        config.vm.define "vte-#{i}" do |vte|
            vte.vm.box = "suse/sless11"
            vte.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/sles-11sp1-x64-vbox4210.box" 
            vte1.vm.hostname="vte-#{i}"
            vte1.vm.network :private_network, ip: "#{EXTRA_MACHINES_BASE_IP}#{i}"
        end 
    end 
end
