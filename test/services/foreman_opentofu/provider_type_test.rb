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
  end
end
