# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

config_path = File.join(File.dirname(__FILE__), "config.yml")
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

# Service ports
openrelik_ui_port = dig_config(cfg, 'service_ports', 'openrelik_ui', default: 8711).to_i
openrelik_api_port = dig_config(cfg, 'service_ports', 'openrelik_api', default: 8710).to_i

# Feature flags
openrelik_run_migrations = dig_config(cfg, 'features', 'openrelik_run_migrations', default: true)
openrelik_workers_enabled = dig_config(cfg, 'features', 'enable_extra_workers', default: true)
enable_wireguard = dig_config(cfg, 'features', 'enable_wireguard', default: true)

# WireGuard endpoint
wg_endpoint = ENV['WG_ENDPOINT'] || dig_config(cfg, 'wireguard', 'endpoint', default: 'se-mma-wg-002')

# Credentials
openrelik_client_id = ENV['OPENRELIK_CLIENT_ID'] || dig_config(cfg, 'credentials', 'openrelik_client_id', default: '')
openrelik_client_secret = ENV['OPENRELIK_CLIENT_SECRET'] || dig_config(cfg, 'credentials', 'openrelik_client_secret', default: '')

# VM Resources
fw_mem = dig_config(cfg, 'resources', 'firewall', 'memory', default: 2048).to_i
fw_cpus = dig_config(cfg, 'resources', 'firewall', 'cpus', default: 2).to_i
or_mem = dig_config(cfg, 'resources', 'openrelik', 'memory', default: 4096).to_i
or_cpus = dig_config(cfg, 'resources', 'openrelik', 'cpus', default: 2).to_i
rx_mem = dig_config(cfg, 'resources', 'remnux', 'memory', default: 4096).to_i
rx_cpus = dig_config(cfg, 'resources', 'remnux', 'cpus', default: 2).to_i

Vagrant.configure("2") do |config|
  # Disable default synced folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Firewall / Gateway VM
  config.vm.define "firewall" do |fw|
    fw.vm.box = "generic/ubuntu2204"
    fw.vm.hostname = "utgard-firewall"

    fw.vm.provider "libvirt" do |lv|
      lv.memory = fw_mem
      lv.cpus = fw_cpus
    end

    # Lab network
    fw.vm.network "private_network",
      ip: lab_firewall_ip,
      netmask: lab_netmask,
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      libvirt__forward_mode: "nat",
      auto_config: true

    # Provision
    fw.vm.provision "file", source: File.join(File.dirname(__FILE__), "ansible"), destination: "/tmp/ansible"
    fw.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "playbooks/firewall.yml"
      ansible.provisioning_path = "/tmp/ansible"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        lab_network: lab_network,
        lab_netmask: lab_netmask,
        lab_gateway: lab_firewall_ip,
        lab_ip: lab_firewall_ip,
        openrelik_ip: openrelik_ip,
        remnux_ip: remnux_ip,
        enable_wireguard: enable_wireguard,
        wg_endpoint: wg_endpoint # Mullvad exit point
      }
    end
  end

  # OpenRelik VM
  config.vm.define "openrelik" do |orv|
    orv.vm.box = "generic/ubuntu2204"
    orv.vm.hostname = "utgard-openrelik"

    orv.vm.provider "libvirt" do |lv|
      lv.memory = or_mem
      lv.cpus = or_cpus
    end

    # Lab network
    orv.vm.network "private_network",
      ip: openrelik_ip,
      netmask: lab_netmask,
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Provision
    orv.vm.provision "file", source: File.join(File.dirname(__FILE__), "ansible"), destination: "/tmp/ansible"
    orv.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "playbooks/openrelik.yml"
      ansible.provisioning_path = "/tmp/ansible"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        openrelik_client_id: openrelik_client_id,
        openrelik_client_secret: openrelik_client_secret,
        openrelik_run_migrations: openrelik_run_migrations,
        openrelik_workers_enabled: openrelik_workers_enabled,
        openrelik_ui_port: openrelik_ui_port,
        openrelik_api_port: openrelik_api_port,
        lab_gateway: lab_firewall_ip,
        lab_ip: openrelik_ip
      }
    end
  end

  # REMnux VM
  config.vm.define "remnux" do |rx|
    rx.vm.box = "generic/ubuntu2204"
    rx.vm.hostname = "utgard-remnux"

    rx.vm.provider "libvirt" do |lv|
      lv.memory = rx_mem
      lv.cpus = rx_cpus
    end

    # Lab network
    rx.vm.network "private_network",
      ip: remnux_ip,
      netmask: lab_netmask,
      libvirt__network_name: "utgard-lab",
      libvirt__dhcp_enabled: false,
      auto_config: true

    # Provision
    rx.vm.provision "file", source: File.join(File.dirname(__FILE__), "ansible"), destination: "/tmp/ansible"
    rx.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "playbooks/remnux.yml"
      ansible.provisioning_path = "/tmp/ansible"
      ansible.compatibility_mode = "2.0"
      ansible.extra_vars = {
        lab_gateway: lab_firewall_ip,
        lab_ip: remnux_ip
      }
    end
  end
end
