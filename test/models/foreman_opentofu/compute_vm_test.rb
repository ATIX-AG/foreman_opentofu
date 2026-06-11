require 'test_plugin_helper'

module ForemanOpentofu
  class ComputeVMTest < ActiveSupport::TestCase
    test '#vm_description uses provider vm labels and skips blank values' do
      provider = mock('provider')
      tofu_provider = mock('tofu_provider')
      provider.stubs(:tofu_provider).returns(tofu_provider)
      tofu_provider.stubs(:attributes).with('vm').returns([
                                                            { 'name' => 'memory', 'label' => 'Memory (MB)' },
                                                            { 'name' => 'resource_pool_id', 'label' => 'Pool' },
                                                            { 'name' => 'empty_value', 'label' => 'Ignored' },
                                                          ])

      vm = ComputeVM.new(provider, 'memory' => 4096, 'resource_pool_id' => 'pool-1', 'empty_value' => '')

      assert_equal 'Memory (MB): 4096, Pool: pool-1', vm.vm_description
    end

    test '#vm_description returns nil when provider has no vm attributes' do
      vm = ComputeVM.new(Object.new, 'name' => 'vm1')

      assert_nil vm.vm_description
    end

    test 'unknown dynamic attributes return nil' do
      vm = ComputeVM.new(Object.new, 'name' => 'vm1')

      assert_nil vm.non_existing_attribute
    end
  end
end
