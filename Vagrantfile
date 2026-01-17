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
remnux_ip = dig_config(cfg, 'lab', 'remnux_ip', default: '10.20.0.20')
win_analysis_ip = dig_config(cfg, 'lab', 'win_analysis_ip', default: '10.20.0.30')

# Feature flags
enable_wireguard = dig_config(cfg, 'features', 'enable_wireguard', default: true)
remnux_snapshot_enabled = dig_config(cfg, 'features', 'remnux_snapshot', default: false)
remnux_snapshot_name = dig_config(cfg, 'features', 'remnux_snapshot_name', default: 'clean')
win_analysis_enabled = dig_config(cfg, 'features', 'windows_analysis_vm', default: false)

# WireGuard endpoint
wg_endpoint = ENV['WG_ENDPOINT'] || dig_config(cfg, 'wireguard', 'endpoint', default: 'se-mma-wg-002')

# VM Resources
fw_mem = dig_config(cfg, 'resources', 'firewall', 'memory', default: 2048).to_i
fw_cpus = dig_config(cfg, 'resources', 'firewall', 'cpus', default: 2).to_i
rx_mem = dig_config(cfg, 'resources', 'remnux', 'memory', default: 4096).to_i
rx_cpus = dig_config(cfg, 'resources', 'remnux', 'cpus', default: 2).to_i
win_mem = dig_config(cfg, 'resources', 'windows_analysis', 'memory', default: 8192).to_i
win_cpus = dig_config(cfg, 'resources', 'windows_analysis', 'cpus', default: 4).to_i

Vagrant.configure("2") do |config|
  # Disable default synced folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  if remnux_snapshot_enabled
    config.trigger.after :up do |t|
      t.only_on = "remnux"
      t.info = "Ensuring REMnux snapshot '#{remnux_snapshot_name}' exists"
      t.run = {
        inline: "vagrant snapshot list remnux 2>/dev/null | grep -q '^#{remnux_snapshot_name}$' || vagrant snapshot save remnux #{remnux_snapshot_name} || true"
      }
    end
  end

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
        remnux_ip: remnux_ip,
        enable_wireguard: enable_wireguard,
        wg_endpoint: wg_endpoint # Mullvad exit point
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

  # Windows Analysis VM (optional)
  if win_analysis_enabled
    config.vm.define "win-analysis" do |win|
      win.vm.box = "gusztavvargadr/windows-10"
      win.vm.hostname = "utgard-win"
      win.vm.communicator = "winrm"
      win.winrm.basic_auth_only = true
      win.winrm.timeout = 300
      win.winrm.retry_limit = 20
      win.winrm.port = 5985

      win.vm.provider "libvirt" do |lv|
        lv.memory = win_mem
        lv.cpus = win_cpus
        lv.disk_bus = "virtio"
        lv.graphics_port = 5900 + rand(1000)
      end

      # Lab network (Vagrant auto-config handles IP assignment)
      win.vm.network "private_network",
        ip: win_analysis_ip,
        netmask: lab_netmask,
        libvirt__network_name: "utgard-lab",
        libvirt__dhcp_enabled: false

      # Provision from host via Ansible (requires: ansible-galaxy collection install community.windows)
      win.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/playbooks/windows.yml"
        ansible.inventory_path = "ansible/inventory.yml"
        ansible.compatibility_mode = "2.0"
        ansible.extra_vars = {
          lab_gateway: lab_firewall_ip,
          lab_ip: win_analysis_ip,
          win_analysis_enabled: true
        }
      end

      # Snapshot for clean state (after provisioning)
      win.trigger.after :provision do |t|
        t.only_on = "win-analysis"
        t.info = "Creating Windows analysis snapshot 'clean'"
        t.run = {inline: "vagrant snapshot save win-analysis clean 2>/dev/null || true"}
      end
    end
  end
end
