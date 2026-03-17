# FIXME: should not be necessary due to autoloading :-(
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('nutanix') do
  # FIXME: Requires Nutanix-server that supports v2-API (see 'available_images')
  # @capabilities = [:build, :image]

  self.provider_attrs = [
    { "name": 'cluster_uuid', "type": 'select', "group": 'vm', "mandatory": true,
      "label": 'Cluster', "options": {
        "data_source": {
          "name": 'nutanix_clusters',
        },
        "output_path_postfix": 'entities',
        "entity": {
          "id": 'metadata.uuid',
        },
      } },
    { "name": 'available_images', "type": 'select', "mandatory": true,
      "label": 'Base-OS-Image', "options": {
        "data_source": {
          "name": 'nutanix_images_v2',
        },
        "entity": { "id": 'ext_id' },
        "output_path_postfix": 'images',
      } },
    { "name": 'num_sockets', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'Sockets' },
    { "name": 'num_vcpus_per_socket', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'Cores per socket' },
    { "name": 'memory_size_mib', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'Memory (MB)' },
    { "name": 'enable_cpu_passthrough', "label": 'CPU Passthrough Enable', "type": 'bool', "group": 'vm', "mandatory": false },
    { "name": 'num_vnuma_nodes', "type": 'number', "group": 'vm', "mandatory": false,
      "label": 'vNUMA Nodes', "help": 'Number of vNUMA nodes. 0 means vNUMA is disabled.' },
    { "name": 'boot_type', "type": 'select', "group": 'vm', "mandatory": false,
      "label": 'Firmware', "options": %w[UEFI LEGACY SECURE_BOOT] },
    { "name": 'power_state', "type": 'select', "group": 'vm', "mandatory": false,
      "options": %w[ON OFF] },
    { "name": 'use_hot_add', "type": 'bool', "group": 'vm', "mandatory": false,
      "help": 'Use Hot Add when modifying VM resources. Passing value false will result in VM reboots. Default value is true.' },
    { "name": 'vga_console_enabled', "type": 'bool', "group": 'vm', "mandatory": false,
      "label": 'VGA Console Enable' },
    { "name": 'disk_size_mib', "type": 'number', "group": 'disk', "mandatory": true,
      "label": 'Size (MB)' },
    { "name": 'nic_type', "type": 'select', "group": 'nic', "mandatory": false,
      "label": 'NIC Type', "options": %w[NORMAL_NIC DIRECT_NIC NETWORK_FUNCTION_NIC] },
    { "name": 'model', "type": 'select', "group": 'nic', "mandatory": true,
      "options": %w[VIRTIO E1000] },
    { "name": 'subnet_uuid', "type": 'select', "group": 'nic', "mandatory": true,
      "label": 'Subnet', "options": { "data_source": { "name": 'nutanix_subnets' }, "output_path_postfix": 'entities', "entity": { "id": 'metadata.uuid' } } },
  ]

  self.disk_renderer = proc do |disk|
    {
      disk_list: {
        disk_size_mib: disk[:size_gb] * 1024,
        storage_config: {
          storage_container_reference: {
            kind: 'storage_container',
            uuid: disk[:container_uuid],
          },
        },
      },
    }
  end

  self.nic_renderer = proc do |nic|
    {
      nic_list: {
        subnet_reference: {
          kind: 'subnet',
          uuid: nic[:subnet_uuid],
        },
        nic_type: nic[:type] || 'NORMAL_NIC',
      },
    }
  end
end
