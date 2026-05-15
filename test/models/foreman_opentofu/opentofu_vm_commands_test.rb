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
      @executor.stubs(:run_output).returns({ 'id' => 'vm-1' })
      vm = @nutanix_cr.find_vm_by_uuid('uuid-1')
      assert_instance_of ComputeVM, vm
    end

    test '#find_vm_by_uuid wraps exceptions' do
      @executor.stubs(:run_output).raises(StandardError.new('boom'))

      assert_raises(Foreman::WrappedException) do
        @nutanix_cr.find_vm_by_uuid('uuid-1')
      end
    end

    context '#new_vm' do
      setup do
        @executor.stubs(:run_fetch)
        @executor.stubs(:run_new).returns(
          'resource_changes' => [
            { 'change' => { 'after' => { 'name' => 'vm1' } } },
          ]
        )
      end

      test 'returns OpenStruct with attributes' do
        vm = @nutanix_cr.new_vm('name' => 'vm1')

        assert_instance_of OpenStruct, vm
        assert_equal 'vm1', vm.name
      end

      test 'prefills mandatory attributes' do
        @nutanix_cr.stubs(:fetch_resource).returns([{ 'id' => 'some_uuid' }])
        @nutanix_cr.expects(:client).with({ cluster_uuid: 'some_uuid', name: 'vm1' }).returns(@executor)
        @nutanix_cr.new_vm('name' => 'vm1')
      end
    end

    context '#create_vm' do
      test 'returns ComputeVM' do
        @executor.stubs(:run_create).returns({ 'id' => 'vm1' })

        vm = @nutanix_cr.create_vm('name' => 'vm1')

        assert_instance_of ComputeVM, vm
      end

      test 'normalizes indexed volume and interface hashes before client call' do
        captured_args = nil
        @nutanix_cr.stubs(:client).with do |args|
          captured_args = args
          true
        end.returns(@executor)
        @executor.stubs(:run_create).returns({ 'id' => 'vm1' })

        @nutanix_cr.create_vm(
          'name' => 'vm1',
          'volumes' => {
            '0' => { 'size' => '13', 'label' => 'disk0' },
          },
          'interfaces_attributes' => {
            '0' => { 'network_id' => 'net-1', 'adapter_type' => 'vmxnet3' },
          }
        )

        assert_kind_of Array, captured_args[:volumes]
        assert_equal '13', captured_args[:volumes][0][:size]
        assert_equal 'disk0', captured_args[:volumes][0][:label]

        assert_kind_of Array, captured_args[:interfaces]
        assert_equal 'net-1', captured_args[:interfaces][0][:network_id]
        assert_equal 'vmxnet3', captured_args[:interfaces][0][:adapter_type]
      end

      test 'wraps exceptions' do
        @executor.stubs(:run_create).raises(StandardError.new('boom'))

        assert_raises(Foreman::WrappedException) do
          @nutanix_cr.create_vm('name' => 'vm1')
        end
      end
    end

    test '#destroy_vm deletes tf_state' do
      tf_state = FactoryBot.create(:tf_state)

      @executor.stubs(:run_destroy)
      assert_difference('ForemanOpentofu::TfState.count', -1) do
        @nutanix_cr.destroy_vm(tf_state.uuid)
      end
    end

    test '#destroy_vm does nothing when tf_state missing' do
      @executor.stubs(:run_destroy)

      assert_nothing_raised do
        @nutanix_cr.destroy_vm('missing')
      end
    end

    test '#start_vm returns true when powered on' do
      @executor.stubs(:run_create).returns(
        'vm' => { 'power_state' => 'on' }
      )

      assert @nutanix_cr.start_vm('vm1')
    end

    test '#stop_vm returns true when powered off' do
      @executor.stubs(:run_create).returns(
        'vm' => { 'power_state' => 'off' }
      )

      assert @nutanix_cr.stop_vm('vm1')
    end

    test '#save_vm updates existing vm and returns ComputeVM without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })

      @executor.stubs(:run_create).returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', { 'cpu' => 4 })
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm updates vm with no attributes without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })
      @nutanix_cr.expects(:client).with(has_entries('name' => 'existing-vm', :cpu => 2)).returns(@executor)

      @executor.stubs(:run_create).returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', [])
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm wraps exceptions and does not create new TfState' do
      FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })

      @executor.stubs(:run_create).raises(StandardError.new('update failed'))

      assert_no_difference('ForemanOpentofu::TfState.count') do
        assert_raises(Foreman::WrappedException) do
          @nutanix_cr.save_vm('uuid1', { 'cpu' => 8 })
        end
      end
    end

    test '#save_vm fails when TfState is missing' do
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('missing').returns({})

      assert_no_difference('ForemanOpentofu::TfState.count') do
        ex = assert_raises(StandardError) do
          @nutanix_cr.save_vm('missing', { 'cpu' => 4 })
        end
        assert_match(/VM with UUID missing does not exist/, ex.message)
      end
    end

    test '#test_connection runs tofu test_connection' do
      @executor.stubs(:run_test_connection)

      @nutanix_cr.test_connection

      assert_empty @nutanix_cr.errors
    end

    test '#test_connection adds error on failure' do
      @executor.stubs(:run_test_connection).raises(StandardError.new('fail'))

      @nutanix_cr.test_connection

      assert @nutanix_cr.errors.any?
    end
  end
end
