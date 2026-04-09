# FIXME: should not be necessary due to autoloading :-(
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('hetzner') do
  @capabilities = [:image]

  def default_volumes
    { name: 'volume1', size: 50, automount: true, format: 'ext4' }
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
      label: 'Automount' },
    { name: 'format', type: 'select', group: 'disk', mandatory: false,
      label: 'Format', options: %w[ext4 xfs] },
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
  ]

  self.disk_renderer = proc do |disk, index = 0|
    disk = disk.with_indifferent_access
    volume_name = disk[:name].presence || "volume#{index + 1}"
    volume_data = {
      name: volume_name,
      size: disk[:size].presence || 50,
      server_id: :"hcloud_server.node1.id",
    }
    volume_data[:automount] = Foreman::Cast.to_bool(disk[:automount]) unless disk[:automount].nil?
    volume_data[:format] = disk[:format] if disk[:format].present?

    {
      resource: {
        type: 'hcloud_volume',
        name: "volume#{index + 1}",
        content: volume_data,
      },
    }
  end
end
