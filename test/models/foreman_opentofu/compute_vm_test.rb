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

    test 'Stackit output exposes MAC and normalized power state' do
      provider = FactoryBot.build_stubbed(:opentofu_stackit_cr)
      vm = ComputeVM.new(provider, 'mac' => '02:00:00:00:00:01', 'vm' => { 'power_state' => 'on' })
      assert_equal '02:00:00:00:00:01', vm.mac
      assert_equal 'on', vm.power
      assert vm.ready?
      assert_not ComputeVM.new(provider, 'vm' => { 'power_state' => 'off' }).ready?
    end

    test 'exposes NIC objects for Foreman to match and consume individually' do
      provider = FactoryBot.build_stubbed(:opentofu_stackit_cr)
      vm = ComputeVM.new(provider, 'interfaces_attributes' => {
        '0' => { 'identifier' => 'eth0', 'network_id' => 'shared', 'mac' => '02:00:00:00:00:01' },
        '1' => { 'identifier' => 'eth1', 'network_id' => 'shared', 'mac' => '02:00:00:00:00:02' },
      })
      nics = vm.interfaces
      nic = OpenStruct.new(identifier: 'eth1', compute_attributes: { 'network_id' => 'shared' })
      selected = vm.select_nic(nics, nic)
      assert_equal '02:00:00:00:00:02', selected.mac
      nics.delete(selected)
      nic = OpenStruct.new(identifier: 'eth0', compute_attributes: { 'network_id' => 'shared' })
      selected = vm.select_nic(nics, nic)
      assert_equal '02:00:00:00:00:01', selected.mac
      nics.delete(selected)
      assert_nil vm.select_nic(nics, nic)
    end

    test 'reload updates the VM state used by the power UI' do
      provider = mock('provider')
      original = ComputeVM.new(provider, 'identity' => 'vm-1', 'power_state' => 'on')
      refreshed = ComputeVM.new(provider, 'identity' => 'vm-1', 'power_state' => 'off')
      provider.expects(:find_vm_by_uuid).with('vm-1').returns(refreshed)

      assert_same original, original.reload
      assert_equal 'off', original.state
      assert_not original.ready?
    end

    test 'unknown dynamic attributes return nil' do
      vm = ComputeVM.new(Object.new, 'name' => 'vm1')

      assert_nil vm.non_existing_attribute
    end
  end
end
