# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Global: disable default synced folder (avoid NFS issues on libvirt)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Firewall / Gateway VM (Multi-homed)
  config.vm.define "firewall" do |fw|
    fw.vm.box = "generic/ubuntu2204"
    fw.vm.hostname = "utgard-firewall"

    fw.vm.provider "libvirt" do |lv|
      lv.memory = 2048
      lv.cpus = 2
    end

    # eth0: vagrant-libvirt network (public/host access) - auto-configured
    # eth1: utgard-lab network (NAT mode for compatibility) - auto-created by Vagrant
    fw.vm.network "private_network",
      ip: "10.20.0.1",
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      libvirt__forward_mode: "nat",
      auto_config: true

    # Forward reverse proxy ports to host
    fw.vm.network "forwarded_port", guest: 8710, host: 8710  # OpenRelik API
    fw.vm.network "forwarded_port", guest: 8711, host: 8711  # OpenRelik UI
    fw.vm.network "forwarded_port", guest: 18080, host: 18080  # Guacamole (via nginx)

    # Copy firewall playbook and run it
    fw.vm.provision "file", source: "provision/firewall.yml", destination: "/tmp/firewall.yml"
    fw.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/firewall.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        # Provide full WireGuard config via environment
        wg0_conf: ENV['MULLVAD_WG_CONF'] || '',
        lab_network: '10.20.0.0/24',
        lab_gateway_ip: '10.20.0.1',
        openrelik_ip: '10.20.0.30',
        remnux_ip: '10.20.0.20'
      }
    end
  end

  # OpenRelik VM (Lab network only)
  config.vm.define "openrelik" do |orv|
    orv.vm.box = "generic/ubuntu2204"
    orv.vm.hostname = "utgard-openrelik"

    orv.vm.provider "libvirt" do |lv|
      lv.memory = 4096
      lv.cpus = 2
    end

    # Only on utgard-lab (isolated), no direct host access - auto-created by Vagrant
    orv.vm.network "private_network",
      ip: "10.20.0.30",
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Copy OpenRelik playbook and run it
    orv.vm.provision "file", source: "provision/openrelik.yml", destination: "/tmp/openrelik.yml"
    orv.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/openrelik.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        openrelik_client_id: ENV['OPENRELIK_CLIENT_ID'] || '',
        openrelik_client_secret: ENV['OPENRELIK_CLIENT_SECRET'] || '',
        openrelik_allowlist: (ENV['OPENRELIK_ALLOWLIST'] || '').split(',').map(&:strip).reject(&:empty?),
        lab_gateway: '10.20.0.1'
      }
    end
  end

  # REMnux Analyst VM (Lab network only)
  config.vm.define "remnux" do |rx|
    rx.vm.box = "generic/ubuntu2204"
    rx.vm.hostname = "utgard-remnux"

    rx.vm.provider "libvirt" do |lv|
      lv.memory = 4096
      lv.cpus = 2
    end

    # Only on utgard-lab (isolated), no direct host access - auto-created by Vagrant
    rx.vm.network "private_network",
      ip: "10.20.0.20",
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Copy REMnux playbook and run it
    rx.vm.provision "file", source: "provision/remnux.yml", destination: "/tmp/remnux.yml"
    rx.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/remnux.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        lab_gateway: '10.20.0.1'
      }
    end
  end

  # Neko Tor Browser VM (Lab network only)
  config.vm.define "neko" do |nk|
    nk.vm.box = "generic/ubuntu2204"
    nk.vm.hostname = "utgard-neko"

    nk.vm.provider "libvirt" do |lv|
      lv.memory = 3072
      lv.cpus = 2
    end

    # Only on utgard-lab (isolated), no direct host access
    nk.vm.network "private_network",
      ip: "10.20.0.40",
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Forward neko ports to host
    nk.vm.network "forwarded_port", guest: 8080, host: 8080  # Neko Web UI
    nk.vm.network "forwarded_port", guest: 8081, host: 8081  # Neko WebRTC broadcast

    # Copy neko playbook and run it
    nk.vm.provision "file", source: "provision/neko.yml", destination: "/tmp/neko.yml"
    nk.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/neko.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        neko_password: ENV['NEKO_PASSWORD'] || 'neko',
        neko_admin_password: ENV['NEKO_ADMIN_PASSWORD'] || 'admin',
        lab_gateway: '10.20.0.1'
      }
    end
  end
end
