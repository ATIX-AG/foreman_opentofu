require 'test_plugin_helper'

module ForemanOpentofu
  class HetznerTest < ActiveSupport::TestCase
    setup do
      @provider = ProviderTypeManager.find('hetzner')
      @compute_resource = stub(default_volumes: [])
    end

    test 'rejects invalid volume sizes' do
      [9, 10_241, 10.5].each do |size|
        error = assert_raises(ArgumentError) do
          @provider.validate_vm!({ name: 'vm1', volumes: [{ size: size }] }, @compute_resource)
        end
        assert_match(/size must be/, error.message)
      end
    end

    test 'requires a format when automount is enabled and rejects unsupported formats' do
      error = assert_raises(ArgumentError) do
        @provider.validate_vm!({ name: 'vm1', volumes: [{ size: 10, automount: '1' }] }, @compute_resource)
      end
      assert_match(/format is required/, error.message)

      error = assert_raises(ArgumentError) do
        @provider.validate_vm!({ name: 'vm1', volumes: [{ size: 10, format: 'btrfs', automount: false }] }, @compute_resource)
      end
      assert_match(/format must be ext4 or xfs/, error.message)

      assert_nothing_raised do
        @provider.validate_vm!({ name: 'vm1', volumes: [{ size: 10, automount: '1', format: 'ext4' }] }, @compute_resource)
      end
    end

    test 'enforces maximum active volumes and ignores deleted volumes' do
      volumes = (0...16).to_h { |index| [index.to_s, { 'size' => 10 }] }
      volumes['16'] = { '_delete' => '1', 'size' => 'invalid' }
      assert_nothing_raised { @provider.validate_vm!({ name: 'vm1', volumes: volumes }, @compute_resource) }

      volumes['16'] = { 'size' => 10 }
      error = assert_raises(ArgumentError) { @provider.validate_vm!({ name: 'vm1', volumes: volumes }, @compute_resource) }
      assert_match(/at most 16 volumes/, error.message)
    end
  end
end
