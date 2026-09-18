# FIXME: should not be necessary due to autoloading :-(
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('hetzner') do
  @capabilities = [:image, :key_pair, :power_status_only]
  self.default_template = 'Hetzner provision default'

  def disk_renderer_collection?
    true
  end

  def provided_attributes
    {
      ip: :vm_ip_address,
      ip6: :vm_ip6_address,
    }
  end

  def vm_ready(_vm)
    # always ready ;-)
    true
  end

  def normalize_interfaces(vm_attrs)
    attrs = vm_attrs.with_indifferent_access
    return attrs if attrs[:interfaces_attributes].present?

    networks = extract_networks(attrs)
    return attrs if networks.blank?

    attrs[:interfaces_attributes] = build_interfaces_attributes(networks)
    attrs
  end

  def extract_networks(attrs)
    attrs.dig(:vm, :network) ||
      attrs.dig('vm', 'network') ||
      attrs[:network] ||
      attrs['network']
  end

  def build_interfaces_attributes(networks)
    Array(networks).each_with_index.to_h do |net, idx|
      nic = net.respond_to?(:with_indifferent_access) ? net.with_indifferent_access : net
      [idx.to_s, { network_id: nic[:network_id].to_s }]
    end
  end

  self.connection_attrs = [
    { name: 'password', type: 'password', mandatory: true, label: 'Token' },
  ]

  self.provider_attrs = [
    { name: 'server_type', type: 'select', group: 'vm', mandatory: true,
      label: 'Server Type', options: {
        data_source: {
          name: 'hcloud_server_types',
          arguments: {},
        },
        entity: {
          id: 'name',
          name: 'description',
        },
        output_path_postfix: 'server_types',
      } },
    { name: 'location', type: 'select', group: 'vm',
      options: {
        data_source: {
          name: 'hcloud_locations',
          arguments: {},
        },
        entity: {
          id: 'name',
          name: 'description',
        },
        output_path_postfix: 'locations',
      } },
    { name: 'backups', type: 'bool', group: 'vm', help: 'Whether backups are enabled.' },
    { name: 'network_id', type: 'select', group: 'nic', mandatory: true,
      label: 'Network', options: {
        data_source: {
          name: 'hcloud_networks',
          arguments: {},
        },
        output_path_postfix: 'networks',
      } },
    { name: 'name', type: 'string', group: 'disk', mandatory: true,
      label: 'Volume Name' },
    { name: 'size', type: 'number', group: 'disk', mandatory: true,
      label: 'Size (GB)' },
    { name: 'automount', type: 'bool', group: 'disk', mandatory: false,
      label: 'Automount', help: 'Requires Format to be set.' },
    { name: 'format', type: 'select', group: 'disk', mandatory: false,
      label: 'Format', help: 'Required when Automount is enabled.', options: %w[ext4 xfs] },
    { name: 'available_images', type: 'select',
      label: 'Base-OS-Image', options: {
        data_source: {
          name: 'hcloud_images',
          arguments: { with_architecture: ['x86'] },
        },
        entity: {
          name: 'description',
        },
        output_path_postfix: 'images',
      } },
    { name: 'available_ssh_keys', type: 'select',
      label: 'SSH-Deployment-Keys', options: {
        data_source: {
          name: 'hcloud_ssh_keys',
        },
        entity: {
          fingerprint: 'fingerprint',
        },
        output_path_postfix: 'ssh_keys',
      } },
  ]

  self.disk_renderer = proc do |_disk, index = 0|
    # build_disks iterates over each disk; emit the for_each resource only once
    next nil unless index.zero?

    attrs = @cr_attrs.respond_to?(:with_indifferent_access) ? @cr_attrs.with_indifferent_access : {}
    defaults = @compute_resource&.default_volumes
    disks = attrs[:volumes].presence || attrs[:volumes_attributes].presence || defaults || {}
    disks_hcl = respond_to?(:to_hcl) ? to_hcl(disks, snippet: false) : '{}'

    # Hetzner need to interate over volumes and to_hcl only inspects string which would
    # fail for 'for' and 'try' functions, therefore,
    # directly send HCL format to the tofu script
    <<~HCL
      locals {
        disks = #{disks_hcl}
      }

      resource "hcloud_volume" "volumes" {
        for_each  = { for k, d in local.disks : tostring(k) => d if try(d["_delete"], "0") != "1" }
        name      = try(each.value.name, "volume-${each.key}")
        size      = try(each.value.size, 20)
        server_id = hcloud_server.node1.id
        automount = try(each.value.automount, null)
        format    = try(each.value.format, null)
      }
    HCL
  end

  self.nic_renderer = proc do |nic, _index = 0|
    network_id = nic['network_id'] || nic[:network_id]
    next nil if network_id.blank?

    ip = nic['ip'] || nic[:ip]
    alias_ips = nic['alias_ips'] || nic[:alias_ips]

    network_block = { network_id: network_id }
    network_block[:ip] = ip if ip.present?
    network_block[:alias_ips] = alias_ips if alias_ips.present?

    { network: network_block }
  end
end
