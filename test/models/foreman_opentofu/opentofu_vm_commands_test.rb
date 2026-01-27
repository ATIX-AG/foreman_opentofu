require 'test_helper'

module ForemanOpentofu
  class OpentofuVMCommandsTest < ActiveSupport::TestCase
    setup do
      @nutanix_cr = FactoryBot.build_stubbed(:opentofu_nutanix_cr)
      @executor = mock('OpentofuExecuter')
      @nutanix_cr.stubs(:client).returns(@executor)
    end

    test '#find_vm_by_uuid returns ComputeVM' do
      FactoryBot.create(:tf_state)
      @executor.stubs(:run).with('output').returns({ 'id' => 'vm-1' })
      vm = @nutanix_cr.find_vm_by_uuid('uuid-1')
      assert_instance_of ComputeVM, vm
    end

    test '#find_vm_by_uuid wraps exceptions' do
      @executor.stubs(:run).raises(StandardError.new('boom'))

      assert_raises(Foreman::WrappedException) do
        @nutanix_cr.find_vm_by_uuid('uuid-1')
      end
    end

    test '#new_vm returns OpenStruct with attributes' do
      @executor.stubs(:run).with('new').returns(
        'resource_changes' => [
          { 'change' => { 'after' => { 'name' => 'vm1' } } },
        ]
      )

      vm = @nutanix_cr.new_vm('name' => 'vm1')

      assert_instance_of OpenStruct, vm
      assert_equal 'vm1', vm.name
    end

    test '#create_vm returns ComputeVM' do
      @executor.stubs(:run).with('create').returns({ 'id' => 'vm1' })

      vm = @nutanix_cr.create_vm('name' => 'vm1')

      assert_instance_of ComputeVM, vm
    end

    test '#create_vm wraps exceptions' do
      @executor.stubs(:run).raises(StandardError.new('boom'))

      assert_raises(Foreman::WrappedException) do
        @nutanix_cr.create_vm('name' => 'vm1')
      end
    end

    test '#destroy_vm deletes tf_state' do
      tf_state = FactoryBot.create(:tf_state)

      @executor.stubs(:run).with('destroy')
      assert_difference('ForemanOpentofu::TfState.count', -1) do
        @nutanix_cr.destroy_vm(tf_state.uuid)
      end
    end

    test '#destroy_vm does nothing when tf_state missing' do
      @executor.stubs(:run).with('destroy')

      assert_nothing_raised do
        @nutanix_cr.destroy_vm('missing')
      end
    end

    test '#start_vm returns true when powered on' do
      @executor.stubs(:run).with('create').returns(
        'vm' => { 'power_state' => 'on' }
      )

      assert @nutanix_cr.start_vm('vm1')
    end

    test '#stop_vm returns true when powered off' do
      @executor.stubs(:run).with('create').returns(
        'vm' => { 'power_state' => 'off' }
      )

      assert @nutanix_cr.stop_vm('vm1')
    end

    test '#save_vm updates existing vm and returns ComputeVM without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')

      @executor.stubs(:run).with('create').returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', [{ 'cpu' => 4 }])
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm updates vm with no attributes without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')

      @executor.stubs(:run).with('create').returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', [])
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm wraps exceptions and does not create new TfState' do
      FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')

      @executor.stubs(:run).raises(StandardError.new('update failed'))

      assert_no_difference('ForemanOpentofu::TfState.count') do
        assert_raises(Foreman::WrappedException) do
          @nutanix_cr.save_vm('uuid1', [{ 'cpu' => 8 }])
        end
      end
    end

    test '#save_vm fails when TfState is missing' do
      assert_no_difference('ForemanOpentofu::TfState.count') do
        ex = assert_raises(StandardError) do
          @nutanix_cr.save_vm('missing', [{ 'cpu' => 4 }])
        end
        assert_match(/VM with UUID missing does not exist/, ex.message)
      end
    end

    test '#test_connection runs tofu test_connection' do
      @executor.stubs(:run).with('test_connection')

      @nutanix_cr.test_connection

      assert_empty @nutanix_cr.errors
    end

    test '#test_connection adds error on failure' do
      @executor.stubs(:run).raises(StandardError.new('fail'))

      @nutanix_cr.test_connection

      assert @nutanix_cr.errors.any?
    end
  end
end
