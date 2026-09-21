require 'test_plugin_helper'

module ForemanOpentofu
  class StackitTest < ActiveSupport::TestCase
    setup do
      @provider = ProviderTypeManager.find('stackit')
      @compute_resource = stub(default_volumes: [])
    end

    test 'accepts inclusive boot and disk size boundaries as integers and strings' do
      [4, '4', 16_000, '16000'].product([1, '1', 16_000, '16000']).each do |boot_size, disk_size|
        assert_nothing_raised do
          @provider.validate_vm!({ boot_volume_size: boot_size, volumes: [{ size: disk_size }] }, @compute_resource)
        end
      end
    end

    test 'rejects missing noninteger and out of range boot sizes' do
      [nil, '', 0, -1, 3, '3', 16_001, '16001', 4.5, '4.0', 'abc', ' 4'].each do |size|
        error = assert_raises(ArgumentError) do
          @provider.validate_vm!({ boot_volume_size: size }, @compute_resource)
        end
        assert_match(/boot_volume_size must be/, error.message)
      end
    end

    test 'rejects missing noninteger and out of range disk sizes' do
      [nil, '', 0, '0', -1, 16_001, '16001', 1.5, '1.0', 'abc', ' 1'].each do |size|
        error = assert_raises(ArgumentError) do
          @provider.validate_vm!({ volumes: [{ size: size }] }, @compute_resource)
        end
        assert_match(/size must be/, error.message)
      end
    end

    test 'uses the default boot size when omitted and ignores deleted disks' do
      assert_nothing_raised do
        @provider.validate_vm!({ volumes: [{ _delete: 1 }, { 'size' => 0, '_delete' => '1' }] }, @compute_resource)
      end
    end

    test 'validates default volumes when explicit volumes are absent or empty' do
      @compute_resource.stubs(:default_volumes).returns({ '0' => { 'size' => 16_001 } })
      [nil, [], {}].each do |volumes|
        assert_raises(ArgumentError) { @provider.validate_vm!({ volumes: volumes }, @compute_resource) }
      end
      assert_nothing_raised do
        @provider.validate_vm!({ 'volumes' => { '0' => { 'size' => '1' } } }, @compute_resource)
      end
    end
  end
end
