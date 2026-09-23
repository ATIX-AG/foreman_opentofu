require 'test_plugin_helper'

module ForemanOpentofu
  class ProviderTypeTest < ActiveSupport::TestCase
    # FIXME: use a non-existing ProviderType and stub the CR_ATTRS instead
    let(:provider_type) { ProviderTypeManager.find('nutanix') }
    let(:compute_resource) { FactoryBot.create(:opentofu_nutanix_cr) }

    test 'has name' do
      assert_not_empty provider_type.name
    end

    test 'has attributes' do
      assert provider_type.attributes?
    end

    test 'finds all attributes' do
      attributes = provider_type.attributes

      assert_not_empty attributes
      assert_not_empty(attributes.select { |a| a['group'] == 'vm' })
      assert_not_empty(attributes.select { |a| a['group'] == 'nic' })
      assert_not_empty(attributes.select { |a| a['group'] == 'disk' })
    end

    test 'finds group attributes' do
      attributes = provider_type.attributes('vm')

      assert_not_empty attributes
      assert_not_empty(attributes.select { |a| a['group'] == 'vm' })
      assert_empty(attributes.select { |a| a['group'] == 'nic' })
      assert_empty(attributes.select { |a| a['group'] == 'disk' })
    end

    test 'find all by key' do
      assert_instance_of Array, provider_type.search_attr_by('name', 'memory_size_mib')
      assert_not_empty provider_type.search_attr_by('name', 'memory_size_mib')
      assert_not_empty provider_type.search_attr_by('name', 'memory_size_mib', 'vm')
      assert_empty provider_type.search_attr_by('name', 'memory_size_mib', 'nic')
      assert_not_empty provider_type.search_attr_by('type', 'number')
      assert_empty provider_type.search_attr_by('not_a', 'thing')
    end

    test 'find one by key' do
      assert_nil provider_type.find_attr_by('not_a', 'thing')
      assert_instance_of ActiveSupport::HashWithIndifferentAccess, provider_type.find_attr_by('name', 'memory_size_mib')
      assert_not_nil provider_type.find_attr_by('name', 'memory_size_mib', 'vm')
      assert_nil provider_type.find_attr_by('name', 'memory_size_mib', 'nic')
      assert_not_nil provider_type.find_attr_by('type', 'number')
    end

    test 'has available_attributes' do
      attr_hash = provider_type.available_attributes

      assert_instance_of ActiveSupport::HashWithIndifferentAccess, attr_hash
      assert_include attr_hash.keys, 'num_sockets'
      assert_equal 'num_sockets', attr_hash['num_sockets']['name']
    end

    test 'available attributes outputs hash with indifferent access' do
      attrs = provider_type.available_attributes

      assert_instance_of ActiveSupport::HashWithIndifferentAccess, attrs
      assert_include attrs.keys, 'num_sockets'
      assert_equal 'num_sockets', attrs['num_sockets']['name']
      assert_equal 'num_sockets', attrs[:num_sockets][:name]
      assert_equal 'num_sockets', attrs[:num_sockets]['name']
    end

    test 'attributes is empty Array if provider_attrs empty or nil' do
      assert_equal [], provider_type.attributes('nogroup')

      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      provider_type1.provider_attrs = nil
      assert_equal [], provider_type1.attributes

      provider_type1.provider_attrs = []
      assert_equal [], provider_type1.attributes
    end

    test 'provider_attrs converts input to HashWithIndifferentAccess' do
      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      provider_type1.provider_attrs = [
        { name: 'num_sockets', group: 'vm', "options": {
          "data_source": {
            "name": 'nutanix_sockets',
          },
        } },
      ]

      attrs = provider_type1.attributes

      assert_instance_of Array, attrs
      assert_instance_of ActiveSupport::HashWithIndifferentAccess, attrs.first

      assert_equal 'num_sockets', attrs.first[:name]
      assert_equal 'num_sockets', attrs.first['name']
      assert_equal 'nutanix_sockets', attrs.first['options'][:data_source][:name]
    end

    test 'connection_attrs converts input to HashWithIndifferentAccess' do
      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      provider_type1.connection_attrs = [{ name: 'password', type: 'password', mandatory: true }]

      attribute = provider_type1.connection_attrs.first

      assert_instance_of ActiveSupport::HashWithIndifferentAccess, attribute
      assert_equal 'password', attribute[:name]
      assert attribute['mandatory']
    end

    test 'providers define their required connection attributes' do
      assert_equal %w[url user password], (provider_type.connection_attrs.map { |attribute| attribute['name'] })
      assert_equal ['password'], (ProviderTypeManager.find('hetzner').connection_attrs.map { |attribute| attribute['name'] })
    end

    test 'providers define their default templates' do
      assert_equal 'Nutanix provision default', provider_type.default_template
      assert_equal 'Hetzner provision default', ProviderTypeManager.find('hetzner').default_template
    end

    test 'no available_attributes raises' do
      provider_type.expects(:attributes?).returns(false)

      assert_raises(RuntimeError) do
        provider_type.available_attributes
      end
    end

    test 'no default_attributes returns nil' do
      provider_type.instance_variable_set(:@default_attributes, nil)
      assert_nil provider_type.default_attributes
    end

    test 'returns default_attributes, if any' do
      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      def_attr = {
        server_type: 'cx23',
        image: 'debian-13',
      }

      provider_type1.instance_variable_set(:@default_attributes, def_attr)
      assert_not_nil provider_type1.default_attributes
      assert_instance_of Hash, provider_type1.default_attributes
      assert_not_empty provider_type1.default_attributes
      assert_equal def_attr, provider_type1.default_attributes
    end

    test 'no default_interfaces returns nil' do
      provider_type.instance_variable_set(:@default_interfaces, nil)
      assert_nil provider_type.default_interfaces
    end

    test 'returns default_interfaces, if any' do
      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      def_attr = {
        nic_type: 'VIRTIO',
      }

      provider_type1.instance_variable_set(:@default_interfaces, def_attr)
      assert_not_nil provider_type1.default_interfaces
      assert_instance_of Hash, provider_type1.default_interfaces
      assert_not_empty provider_type1.default_interfaces
      assert_equal def_attr, provider_type1.default_interfaces
    end

    test 'no default_volumes returns nil' do
      provider_type.instance_variable_set(:@default_volumes, nil)
      assert_nil provider_type.default_volumes
    end

    test 'returns default_volumes, if any' do
      provider_type1 = ForemanOpentofu::ProviderType.new(provider_type.id)
      def_attr = {
        volume_type: 'something',
      }

      provider_type1.instance_variable_set(:@default_volumes, def_attr)
      assert_not_nil provider_type1.default_volumes
      assert_instance_of Hash, provider_type1.default_volumes
      assert_not_empty provider_type1.default_volumes
      assert_equal def_attr, provider_type1.default_volumes
    end

    test 'available_images() raises Exception if attribute not available or supported' do
      provider_type.expects(:find_attr_by).returns nil
      assert_raise(NotImplementedError) do
        provider_type.available_images(compute_resource)
      end

      provider_type.expects(:find_attr_by).returns({ 'options' => nil })
      assert_raise(NotImplementedError) do
        provider_type.available_images(compute_resource)
      end

      provider_type.expects(:find_attr_by).returns({ 'options' => 1 })
      assert_raise(RuntimeError) do
        provider_type.available_images(compute_resource)
      end
    end

    test 'available_images() requests resource if dynamic value' do
      opts = { 'data_source' => { 'name' => 'test' } }
      provider_type.expects(:find_attr_by).returns({ 'options' => opts })
      compute_resource.expects(:available_resource).with('test', opts)
      provider_type.available_images(compute_resource)
    end

    test 'available_images() returns array if fixed options' do
      opts = %w[option1 option2]
      provider_type.expects(:find_attr_by).returns({ 'options' => opts })
      assert_equal opts, provider_type.available_images(compute_resource)
    end

    test 'available_ssh_keys() returns empty array if attribute not available or supported' do
      provider_type.expects(:find_attr_by).returns nil
      assert_empty provider_type.available_ssh_keys(compute_resource)

      provider_type.expects(:find_attr_by).returns({ 'options' => nil })
      assert_empty provider_type.available_ssh_keys(compute_resource)

      provider_type.expects(:find_attr_by).returns({ 'options' => 1 })
      assert_raise(RuntimeError) do
        assert_empty provider_type.available_ssh_keys(compute_resource)
      end

      provider_type.expects(:find_attr_by).returns({ 'options' => %w[opt1 opt2] })
      assert_raise(RuntimeError) do
        assert_empty provider_type.available_ssh_keys(compute_resource)
      end
    end

    test 'available_ssh_keys() requests resource if dynamic value' do
      opts = { 'data_source' => { 'name' => 'test' } }
      provider_type.expects(:find_attr_by).returns({ 'options' => opts })
      compute_resource.expects(:available_resource).with('test', opts)
      provider_type.available_ssh_keys(compute_resource)
    end

    test 'reset_cached_ssh_keys()' do
      provider_type.expects(:find_attr_by).returns(nil)
      assert_empty provider_type.reset_cached_ssh_keys compute_resource

      provider_type.expects(:find_attr_by).returns({ 'options' => 1 })
      assert_nil provider_type.reset_cached_ssh_keys compute_resource

      provider_type.expects(:find_attr_by).returns({ 'options' => {} })
      compute_resource.expects(:cache_delete)
      provider_type.reset_cached_ssh_keys compute_resource
    end

    test 'provided_attributes()' do
      assert_instance_of Hash, provider_type.provided_attributes
    end

    test 'hetzner renders disk as hcloud_volume resource data' do
      hetzner = ProviderTypeManager.find('hetzner')

      rendered = hetzner.render_disk({ size: 50, format: 'ext4', automount: true }, nil, 0)

      assert_instance_of String, rendered
      assert_includes rendered, 'resource "hcloud_volume" "volumes"'
      assert_includes rendered, 'for_each  = { for k, d in local.disks'
      assert_includes rendered, 'server_id = hcloud_server.node1.id'
      assert_includes rendered, 'automount = try(each.value.automount, null)'
      assert_includes rendered, 'format    = try(each.value.format, null)'
    end

    context 'filter_resource_changes' do
      test 'empty if blank' do
        assert_equal [], provider_type.filter_resource_changes(nil)
        assert_equal [], provider_type.filter_resource_changes([])
      end

      test 'same if no allow-list' do
        provider_type.recreate_type_allow_list = nil
        assert_equal [{ 'type' => 'ignored' }, { 'type' => 'ignored-2' }], provider_type.filter_resource_changes([{ 'type' => 'ignored' }, { 'type' => 'ignored-2' }])
      end

      test 'remove based on allow-list' do
        provider_type.recreate_type_allow_list = %w[allowed allowed-2]
        assert_equal [{ 'type' => 'ignored' }], provider_type.filter_resource_changes([{ 'type' => 'allowed' }, { 'type' => 'ignored' }])
      end
    end

    test 'hetzner marks disk renderer as collection-based' do
      assert ProviderTypeManager.find('hetzner').disk_renderer_collection?
    end

    test 'provider type defaults to non-collection disk rendering' do
      assert_not ProviderType.new('custom').disk_renderer_collection?
    end

    test 'stackit supports image provisioning and power actions without deployment keys' do
      stackit = ProviderTypeManager.find('stackit')

      assert_equal 'Stackit', stackit.name
      assert_includes ProviderTypeManager.enabled_provider_types, stackit
      assert_equal [:image, :key_pair], stackit.capabilities
      assert_equal 'Stackit provision default', stackit.default_template
      assert_equal %w[user password], (stackit.connection_attrs.map { |attribute| attribute['name'] })
      assert_equal({ ip: :vm_ip_address, mac: :mac }, stackit.provided_attributes)
      assert stackit.vm_ready(OpenStruct.new(ready?: true))
      assert_not stackit.vm_ready(OpenStruct.new(ready?: false))
      assert_equal 64, stackit.default_attributes['boot_volume_size']
      assert_not stackit.default_attributes['assign_public_ip']
      assert stackit.find_attr_by('name', 'region', 'vm')['mandatory']
      assert_nil stackit.find_attr_by('name', 'project_id', 'vm')
      assert_equal 'eu01', stackit.default_attributes['region']
      assert_not stackit.find_attr_by('name', 'network_id')['mandatory']
      assert_not stackit.find_attr_by('name', 'security_group_id')['mandatory']
      assert_equal %w[network_id security_group_id], (stackit.attributes('nic').map { |attribute| attribute['name'] })
      assert_equal %w[name size volume_availability_zone performance_class], (stackit.attributes('disk').map { |attribute| attribute['name'] })
      assert stackit.disk_renderer_collection?
      assert_empty stackit.available_images(nil)
    end

    test 'stackit power plans allow only server status updates' do
      stackit = ProviderTypeManager.find('stackit')
      change = {
        'address' => 'stackit_server.node1',
        'change' => {
          'actions' => ['update'],
          'before' => { 'desired_status' => 'active', 'machine_type' => 'g2i.1' },
          'after' => { 'desired_status' => 'inactive', 'machine_type' => 'g2i.1' },
        },
      }
      assert stackit.power_change_allowed?(change)
      change['change']['after']['machine_type'] = 'g2i.2'
      assert_not stackit.power_change_allowed?(change)
      change['change']['actions'] = ['delete']
      assert_not stackit.power_change_allowed?(change)
      assert_not stackit.power_change_allowed?('address' => 'stackit_network.interfaces["0"]', 'change' => { 'actions' => ['delete'] })
    end

    test 'stackit accepts computed metadata becoming unknown during power updates' do
      stackit = ProviderTypeManager.find('stackit')
      resource = {
        'address' => 'stackit_server.node1',
        'change' => {
          'actions' => ['update'],
          'before' => {
            'desired_status' => 'active', 'machine_type' => 'g2i.1',
            'agent' => { 'provisioned' => true, 'provisioning_policy' => 'INHERIT' },
            'launched_at' => '2026-09-23T10:31:25Z', 'updated_at' => '2026-09-23T10:31:25Z'
          },
          'after' => { 'desired_status' => 'inactive', 'machine_type' => 'g2i.1', 'agent' => nil },
          'after_unknown' => { 'agent' => true, 'launched_at' => true, 'updated_at' => true },
        },
      }
      assert stackit.power_change_allowed?(resource)

      resource['change']['after']['machine_type'] = nil
      resource['change']['after_unknown']['machine_type'] = true
      assert_not stackit.power_change_allowed?(resource)
    end

    test 'stackit accepts nested computed agent fields but rejects a changed policy' do
      stackit = ProviderTypeManager.find('stackit')
      resource = {
        'address' => 'stackit_server.node1',
        'change' => {
          'actions' => ['update'],
          'before' => { 'agent' => { 'provisioned' => true, 'provisioning_policy' => 'INHERIT' } },
          'after' => { 'agent' => { 'provisioning_policy' => 'INHERIT' } },
          'after_unknown' => { 'agent' => { 'provisioned' => true } },
        },
      }
      assert stackit.power_change_allowed?(resource)
      resource['change']['after']['agent']['provisioning_policy'] = 'NEVER'
      assert_not stackit.power_change_allowed?(resource)
    end

    test 'stackit matches MACs by interface identifier before network' do
      stackit = ProviderTypeManager.find('stackit')
      first = { 'identifier' => 'eth0', 'network_id' => 'shared', 'mac' => '02:00:00:00:00:01' }
      second = { 'identifier' => 'eth1', 'network_id' => 'shared', 'mac' => '02:00:00:00:00:02' }
      nic = OpenStruct.new(identifier: 'eth1', compute_attributes: { 'network_id' => 'shared' })
      assert_equal second, stackit.select_nic_for_mac([first, second], nic)
      nic = OpenStruct.new(identifier: 'eth2', compute_attributes: { 'network_id' => 'missing' })
      assert_nil stackit.select_nic_for_mac([first], nic)
    end

    test 'stackit retains protection against server and network replacement' do
      changes = [{ 'type' => 'stackit_server' }, { 'type' => 'stackit_network_interface' }]

      assert_equal changes, ProviderTypeManager.find('stackit').filter_resource_changes(changes)
    end

    test 'only stackit opts out of planning during form initialization' do
      assert ProviderType.new('custom').plan_on_new_vm?
      assert ProviderTypeManager.find('nutanix').plan_on_new_vm?
      assert ProviderTypeManager.find('hetzner').plan_on_new_vm?
      assert_not ProviderTypeManager.find('stackit').plan_on_new_vm?
    end
  end
end
