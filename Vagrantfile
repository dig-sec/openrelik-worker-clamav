# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

config_path = File.join(File.dirname(__FILE__), "provision/config.yml")
cfg = File.exist?(config_path) ? YAML.load_file(config_path) : {}

def dig_config(cfg, *keys, default: nil)
  keys.reduce(cfg) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil } || default
end

# Lab network configuration
lab_network = dig_config(cfg, 'lab', 'network', default: '10.20.0.0/24')
lab_netmask = dig_config(cfg, 'lab', 'netmask', default: '255.255.255.0')
lab_firewall_ip = dig_config(cfg, 'lab', 'firewall_ip', default: '10.20.0.2')
openrelik_ip = dig_config(cfg, 'lab', 'openrelik_ip', default: '10.20.0.30')
remnux_ip = dig_config(cfg, 'lab', 'remnux_ip', default: '10.20.0.20')
neko_ip = dig_config(cfg, 'lab', 'neko_ip', default: '10.20.0.40')
host_network_cidr = dig_config(cfg, 'host', 'network_cidr', default: '192.168.121.0/24')

# Feature flags (Guacamole removed - using Pangolin for remote access)
enable_extra_workers = dig_config(cfg, 'features', 'enable_extra_workers', default: false)
openrelik_run_migrations = dig_config(cfg, 'features', 'openrelik_run_migrations', default: true)

# Credentials (env vars take precedence)
neko_password = ENV['NEKO_PASSWORD'] || dig_config(cfg, 'credentials', 'neko_password', default: 'neko')
neko_admin_password = ENV['NEKO_ADMIN_PASSWORD'] || dig_config(cfg, 'credentials', 'neko_admin_password', default: 'admin')

# VM Resources
fw_mem = dig_config(cfg, 'resources', 'firewall', 'memory', default: 2048).to_i
fw_cpus = dig_config(cfg, 'resources', 'firewall', 'cpus', default: 2).to_i
or_mem = dig_config(cfg, 'resources', 'openrelik', 'memory', default: 8192).to_i
or_cpus = dig_config(cfg, 'resources', 'openrelik', 'cpus', default: 4).to_i
rx_mem = dig_config(cfg, 'resources', 'remnux', 'memory', default: 4096).to_i
rx_cpus = dig_config(cfg, 'resources', 'remnux', 'cpus', default: 2).to_i
nk_mem = dig_config(cfg, 'resources', 'neko', 'memory', default: 3072).to_i
nk_cpus = dig_config(cfg, 'resources', 'neko', 'cpus', default: 2).to_i

Vagrant.configure("2") do |config|
  # Global: disable default synced folder (avoid NFS issues on libvirt)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Firewall / Gateway VM (Multi-homed)
  config.vm.define "firewall" do |fw|
    fw.vm.box = "generic/ubuntu2204"
    fw.vm.hostname = "utgard-firewall"

    fw.vm.provider "libvirt" do |lv|
      lv.memory = fw_mem
      lv.cpus = fw_cpus
    end

    # eth0: vagrant-libvirt network (public/host access) - auto-configured
    # eth1: utgard-lab network (NAT mode for compatibility) - auto-created by Vagrant
    fw.vm.network "private_network",
      ip: lab_firewall_ip,
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      libvirt__forward_mode: "nat",
      auto_config: true

    # NOTE: Port forwarding removed - use Pangolin for external access
    # See docs/PANGOLIN-ACCESS.md for setup instructions

    # Copy firewall playbook, tasks, and supporting files
    fw.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/firewall-main.yml"), destination: "/tmp/firewall-main.yml"
    fw.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/tasks"), destination: "/tmp/tasks"
    fw.vm.provision "file", source: File.join(File.dirname(__FILE__), "services/index.html.j2"), destination: "/tmp/index.html.j2"
    fw.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/firewall-main.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        wg0_conf: ENV['MULLVAD_WG_CONF'] || '',
        lab_network: lab_network,
        firewall_ip: lab_firewall_ip,
        openrelik_ip: openrelik_ip,
        remnux_ip: remnux_ip,
        neko_ip: neko_ip,
        host_network_cidr: host_network_cidr
      }
    end
  end

  # OpenRelik VM (Lab network only)
  config.vm.define "openrelik" do |orv|
    orv.vm.box = "generic/ubuntu2204"
    orv.vm.hostname = "utgard-openrelik"

    orv.vm.provider "libvirt" do |lv|
      lv.memory = or_mem
      lv.cpus = or_cpus
    end

    # Only on utgard-lab (isolated), no direct host access - auto-created by Vagrant
    orv.vm.network "private_network",
      ip: openrelik_ip,
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Copy OpenRelik playbook and tasks
    orv.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/openrelik-main.yml"), destination: "/tmp/openrelik-main.yml"
    orv.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/tasks"), destination: "/tmp/tasks"
    # Copy patches only if the local patches directory exists
    if File.directory?(File.join(File.dirname(__FILE__), 'patches'))
      orv.vm.provision "file", source: "patches", destination: "/tmp/patches"
    end
    orv.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/openrelik-main.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        openrelik_client_id: ENV['OPENRELIK_CLIENT_ID'] || '',
        openrelik_client_secret: ENV['OPENRELIK_CLIENT_SECRET'] || '',
        openrelik_allowlist: (ENV['OPENRELIK_ALLOWLIST'] || '').split(',').map(&:strip).reject(&:empty?),
        lab_gateway: lab_firewall_ip,
        lab_ip: openrelik_ip,
        enable_extra_workers: enable_extra_workers,
        openrelik_run_migrations: openrelik_run_migrations
      }
    end
  end

  # REMnux Analyst VM (Lab network only)
  config.vm.define "remnux" do |rx|
    rx.vm.box = "generic/ubuntu2204"
    rx.vm.hostname = "utgard-remnux"

    rx.vm.provider "libvirt" do |lv|
      lv.memory = rx_mem
      lv.cpus = rx_cpus
    end

    # Only on utgard-lab (isolated), no direct host access - auto-created by Vagrant
    rx.vm.network "private_network",
      ip: remnux_ip,
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Copy REMnux playbook and tasks
    rx.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/remnux-main.yml"), destination: "/tmp/remnux-main.yml"
    rx.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/tasks"), destination: "/tmp/tasks"
    rx.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/remnux-main.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        lab_gateway: lab_firewall_ip,
        lab_ip: remnux_ip
      }
    end
  end

  # Neko Tor Browser VM (Lab network only)
  config.vm.define "neko" do |nk|
    nk.vm.box = "generic/ubuntu2204"
    nk.vm.hostname = "utgard-neko"

    nk.vm.provider "libvirt" do |lv|
      lv.memory = nk_mem
      lv.cpus = nk_cpus
    end

    # Only on utgard-lab (isolated), no direct host access
    nk.vm.network "private_network",
      ip: neko_ip,
      netmask: "255.255.255.0",
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Access WebRTC via Pangolin (no host port forwarding)

    # Copy neko playbook and tasks
    nk.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/neko-main.yml"), destination: "/tmp/neko-main.yml"
    nk.vm.provision "file", source: File.join(File.dirname(__FILE__), "provision/tasks"), destination: "/tmp/tasks"
    nk.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "/tmp/neko-main.yml"
      ansible.provisioning_path = "/tmp"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        neko_password: neko_password,
        neko_admin_password: neko_admin_password,
        lab_gateway: lab_firewall_ip,
        neko_webrtc_ip: ENV['NEKO_WEBRTC_IP'] || neko_ip
      }
    end
  end
end
