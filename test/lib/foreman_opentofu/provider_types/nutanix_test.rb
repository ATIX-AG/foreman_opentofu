require 'test_plugin_helper'

module ForemanOpentofu
  class NutanixTest < ActiveSupport::TestCase
    setup do
      @provider = ProviderTypeManager.find('nutanix')
      @compute_resource = stub(default_volumes: [])
    end

    test 'rejects nonpositive and noninteger CPU and memory values' do
      [:num_sockets, :num_vcpus_per_socket, :memory_size_mib].product([0, '0', -1, 1.5, '1.0', 'abc', ' 1']).each do |name, value|
        error = assert_raises(ArgumentError) { @provider.validate_vm!({ name => value }, @compute_resource) }
        assert_match(/#{name} must be/, error.message)
      end
    end

    test 'rejects missing nonpositive and noninteger disk sizes' do
      [nil, '', 0, '0', -1, 1.5, '1.0', 'abc'].each do |size|
        error = assert_raises(ArgumentError) do
          @provider.validate_vm!({ volumes: [{ disk_size_mib: size }] }, @compute_resource)
        end
        assert_match(/disk_size_mib must be/, error.message)
      end
    end

    test 'ignores deleted disks with invalid sizes' do
      assert_nothing_raised do
        @provider.validate_vm!({ volumes: [{ _delete: 1 }, { 'disk_size_mib' => 0, '_delete' => '1' }] }, @compute_resource)
      end
    end

    test 'validates default volumes when explicit volumes are absent or empty' do
      @compute_resource.stubs(:default_volumes).returns({ '0' => { 'disk_size_mib' => 0 } })
      [nil, [], {}].each do |volumes|
        assert_raises(ArgumentError) { @provider.validate_vm!({ volumes: volumes }, @compute_resource) }
      end
      assert_nothing_raised { @provider.validate_vm!({ volumes: [{ disk_size_mib: 1 }] }, @compute_resource) }
    end
  end
end
