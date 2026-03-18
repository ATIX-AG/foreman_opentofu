# FIXME: should not be necessary due to autoloading :-(
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('hetzner') do
  @capabilities = [:image]

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
end
