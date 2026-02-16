module ForemanOpentofu
  class ProviderTypeTest < ActiveSupport::TestCase
    # FIXME: use a non-existing ProviderType and stub the CR_ATTRS instead
    let(:provider_type) { ProviderType.new('nutanix') }

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

      assert_instance_of Hash, attr_hash
      assert_include attr_hash.keys, 'num_sockets'
      assert_equal 'num_sockets', attr_hash['num_sockets']['name']
    end

    test 'no available_attributes raises' do
      provider_type.expects(:attributes?).returns(false)

      assert_raises(RuntimeError) do
        provider_type.available_attributes
      end
    end

    test 'no default_attributes returns nil' do
      assert_nil provider_type.default_attributes
    end

    test 'returns default_attributes, if any' do
      def_attr = {
        'server_type' => 'cx23',
        'image' => 'debian-13',
      }

      provider_type.instance_eval do
        @default_attributes = def_attr
      end

      assert_not_nil provider_type.default_attributes
      assert_instance_of Hash, provider_type.default_attributes
      assert_not_empty provider_type.default_attributes
      assert_equal def_attr, provider_type.default_attributes
    end
  end
end
