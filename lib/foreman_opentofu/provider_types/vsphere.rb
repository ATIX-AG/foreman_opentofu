# FIXME: should not be necessary due to autoloading :-(
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('vsphere') do
  def default_volumes
    { label: 'disk0', size: 20 }
  end

  def default_interfaces
    [{ network_id: '', adapter_type: 'vmxnet3' }]
  end

  self.provider_attrs = [
    { "name": 'resource_pool_id', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'resource_pool_id' },
    { "name": 'memory', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'Memory (MB)' },
    { "name": 'num_cpus', "label": 'Cpus', "type": 'number', "group": 'vm', "mandatory": false },
    { "name": 'network_id', "type": 'string', "group": 'nic', "mandatory": true,
      "label": 'Network', "data_source": true },
    { "name": 'adapter_type', "type": 'select', "group": 'nic', "mandatory": false,
      "label": 'Adapter Type', "options": %w[e1000 e1000e sriov vmxnet3] },
    { "name": 'size', "type": 'number', "group": 'disk', "mandatory": true,
      "label": 'Size (GB)' },
    { "name": 'label', "type": 'string', "group": 'disk', "mandatory": true,
      "label": 'Label' },
  ]

  self.disk_renderer = proc do |disk, index = 0|
    unit_number = index >= 7 ? index + 1 : index

    {
      disk: {
        label: disk[:label] || "disk#{index}",
        size: disk[:size] || 20,
        unit_number: unit_number,
      },
    }
  end

  self.nic_renderer = proc do |nic, _index = 0|
    nic = nic.with_indifferent_access

    {
      network_interface: {
        network_id: nic[:network_id] || '',
        adapter_type: nic[:adapter_type] || nic[:model] || 'vmxnet3',
      },
    }
  end
end
