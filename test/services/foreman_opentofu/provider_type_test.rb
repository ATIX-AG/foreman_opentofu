module ForemanOpentofu
  class ProviderTypeTest < ActiveSupport::TestCase
    # FIXME: use a non-existing ProviderType and stub the CR_ATTRS instead
    let(:provider_type) { ProviderTypeManager.find('nutanix') }

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
  end
end
