require 'test_plugin_helper'

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

    test '#find_vm_by_uuid keeps volumes with id' do
      FactoryBot.create(:tf_state)
      @executor.stubs(:run_output).returns({
        'id' => 'vm-1',
        'volumes_attributes' => { '0' => { 'name' => 'voo', 'id' => 123 } },
      })
      vm = @nutanix_cr.find_vm_by_uuid('uuid-1')
      assert_instance_of ComputeVM, vm
      assert_not_empty vm['volumes_attributes']
    end

    test '#find_vm_by_uuid removes volumes without id' do
      FactoryBot.create(:tf_state)
      @executor.stubs(:run_output).returns({
        'id' => 'vm-1',
        'volumes_attributes' => { '0' => { 'name' => 'voo', 'id' => nil } },
      })
      vm = @nutanix_cr.find_vm_by_uuid('uuid-1')
      assert_instance_of ComputeVM, vm
      assert_empty vm['volumes_attributes']
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

      test 'returns ComputeVM with attributes' do
        vm = @nutanix_cr.new_vm('name' => 'vm1')

        assert_instance_of ComputeVM, vm
        assert_equal 'vm1', vm.name
      end

      test 'preserves requested attributes missing from terraform after data' do
        vm = @nutanix_cr.new_vm('name' => 'vm1', 'memory_size_mib' => 2048)

        assert_equal 2048, vm.memory_size_mib
        assert_equal({ 'name' => 'vm1', 'memory_size_mib' => 2048 }, vm.to_h.slice('name', 'memory_size_mib'))
      end

      test 'prefills mandatory attributes' do
        @nutanix_cr.stubs(:fetch_resource).returns([{ 'id' => 'some_uuid' }])
        @nutanix_cr.expects(:client).with({ cluster_uuid: 'some_uuid', name: 'vm1' }).returns(@executor)
        @nutanix_cr.new_vm('name' => 'vm1')
      end

      test 'stackit builds an empty form without invoking OpenTofu' do
        stackit_cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
        stackit_cr.expects(:client).never

        vm = stackit_cr.new_vm

        assert_instance_of ComputeVM, vm
        assert_not vm.persisted?
        assert_equal 64, vm.boot_volume_size
        assert_not vm.assign_public_ip
        assert_equal 'eu01', vm.region
        assert_nil vm.network_id
        assert_nil vm.security_group_id
        assert_equal '', vm.machine_type
      end

      test 'stackit preserves compute profile values while building the form locally' do
        stackit_cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
        stackit_cr.expects(:client).never

        vm = stackit_cr.new_vm(
          'name' => 'stackit-vm',
          'machine_type' => 'g2i.1',
          'region' => 'eu02',
          'network_id' => '11111111-1111-4111-8111-111111111111',
          'security_group_id' => '22222222-2222-4222-8222-222222222222',
          'boot_volume_size' => 80,
          'assign_public_ip' => '0'
        )

        assert_equal 'stackit-vm', vm.name
        assert_equal 'g2i.1', vm.machine_type
        assert_equal 'eu02', vm.region
        assert_equal '11111111-1111-4111-8111-111111111111', vm.network_id
        assert_equal '22222222-2222-4222-8222-222222222222', vm.security_group_id
        assert_equal 80, vm.boot_volume_size
        assert_not vm.assign_public_ip
        assert_not vm.persisted?
      end
    end

    context '#create_vm' do
      test 'stackit still invokes OpenTofu on actual creation' do
        stackit_cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
        stackit_cr.expects(:client).with(has_entries(name: 'stackit-vm')).returns(@executor)
        @executor.expects(:run_create).with(cleanup_on_failure: true).returns({ 'identity' => 'server-id' })

        vm = stackit_cr.create_vm('name' => 'stackit-vm')

        assert_equal 'server-id', vm['identity']
      end

      test 'returns ComputeVM' do
        @executor.stubs(:run_create).with(cleanup_on_failure: true).returns({ 'id' => 'vm1' })

        vm = @nutanix_cr.create_vm('name' => 'vm1')

        assert_instance_of ComputeVM, vm
      end

      test 'normalizes indexed volume and interface hashes before client call' do
        captured_args = nil
        @nutanix_cr.stubs(:client).with do |args|
          captured_args = args
          true
        end.returns(@executor)
        @executor.stubs(:run_create).with(cleanup_on_failure: true).returns({ 'id' => 'vm1' })

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

      test 'drops collection placeholders and unsaved deleted entries before client call' do
        captured_args = nil
        @nutanix_cr.stubs(:client).with do |args|
          captured_args = args
          true
        end.returns(@executor)
        @executor.stubs(:run_create).with(cleanup_on_failure: true).returns({ 'id' => 'vm1' })

        @nutanix_cr.create_vm(
          'name' => 'vm1',
          'volumes' => {
            '0' => { 'size' => '13', 'label' => 'disk0' },
            'new_volumes' => { 'size' => '99', 'label' => 'ignored-placeholder' },
            'new_123' => { 'size' => '20', 'label' => 'disk1' },
            '1' => { '_delete' => '1', 'size' => '30', 'label' => 'deleted-disk' },
          },
          'interfaces_attributes' => {
            '0' => { 'network_id' => 'net-1', 'adapter_type' => 'vmxnet3' },
            'new_interfaces' => { 'network_id' => 'ignored' },
            'new_456' => { 'network_id' => 'net-2', 'adapter_type' => 'e1000' },
            '1' => { '_delete' => '1', 'network_id' => 'net-3', 'adapter_type' => 'e1000' },
          }
        )

        assert_equal [
          { size: '13', label: 'disk0' },
          { size: '20', label: 'disk1' },
        ], captured_args[:volumes]

        assert_equal [
          { network_id: 'net-1', adapter_type: 'vmxnet3' },
          { network_id: 'net-2', adapter_type: 'e1000' },
        ], captured_args[:interfaces]
      end

      test 'wraps exceptions' do
        @executor.stubs(:run_create).with(cleanup_on_failure: true).raises(StandardError.new('boom'))

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

    test 'stackit power actions accept UUID or name and reuse the complete VM output' do
      cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
      tf_state = FactoryBot.create(:tf_state, uuid: 'stackit-uuid', name: 'stackit-vm')
      inputs = {
        'region' => 'eu02', 'machine_type' => 'g2i.1', 'image_id' => 'image-1',
        'interfaces_attributes' => { '0' => { 'network_id' => 'generated-network', 'managed_network' => true } },
        'volumes_attributes' => { '2' => { 'name' => 'data', 'size' => 80, 'performance_class' => nil } },
        'user_data' => '#cloud-config', 'assign_public_ip' => true
      }
      reader = mock('state reader')
      cr.expects(:client).with('name' => tf_state.name).twice.returns(reader)
      reader.expects(:run_output).twice.returns(
        'vm' => inputs.except('interfaces_attributes', 'volumes_attributes'),
        'interfaces_attributes' => inputs['interfaces_attributes'],
        'volumes_attributes' => inputs['volumes_attributes']
      )
      %w[off on].each do |state|
        writer = mock("power #{state}")
        cr.expects(:client).with(inputs.merge('name' => tf_state.name, 'power_state' => state)).returns(writer)
        writer.expects(:run_create).with(power_only: true).returns('vm' => { 'power_state' => state })
      end
      stopped_vm = cr.stop_vm(tf_state.uuid)
      started_vm = cr.start_vm(tf_state.name)
      assert_instance_of ComputeVM, stopped_vm
      assert_instance_of ComputeVM, started_vm
      assert_equal 'off', stopped_vm.power
      assert_equal 'on', started_vm.power
      assert_not inputs.key?('power_state')
    end

    test 'stackit does not report success when the returned power state differs' do
      cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
      tf_state = FactoryBot.create(:tf_state, uuid: 'power-uuid', name: 'power-vm')
      cr.stubs(:client).returns(@executor)
      @executor.expects(:run_output).returns('vm' => { 'name' => tf_state.name })
      @executor.expects(:run_create).with(power_only: true).returns('vm' => { 'power_state' => 'on' })
      assert_raises(Foreman::WrappedException) { cr.stop_vm(tf_state.uuid) }
    end

    test 'stackit refuses power changes without VM output' do
      cr = FactoryBot.build_stubbed(:opentofu_stackit_cr)
      tf_state = FactoryBot.create(:tf_state, uuid: 'legacy-uuid', name: 'legacy-vm')
      cr.expects(:client).with('name' => tf_state.name).returns(@executor)
      @executor.expects(:run_output).returns({})
      @executor.expects(:run_create).never
      assert_raises(Foreman::WrappedException) { cr.stop_vm(tf_state.uuid) }
    end

    test '#save_vm updates existing vm and returns ComputeVM without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })

      @executor.stubs(:run_create).with(raise_if_recreate: true).returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', { 'cpu' => 4 })
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm updates vm with no attributes without creating new TfState' do
      tf_state = FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })
      @nutanix_cr.expects(:client).with(has_entries('name' => 'existing-vm', :cpu => 2)).returns(@executor)

      @executor.stubs(:run_create).with(raise_if_recreate: true).returns({ 'id' => tf_state.uuid })

      assert_no_difference('ForemanOpentofu::TfState.count') do
        vm = @nutanix_cr.save_vm('uuid1', [])
        assert_instance_of ComputeVM, vm
      end
    end

    test '#save_vm wraps exceptions and does not create new TfState' do
      FactoryBot.create(:tf_state, uuid: 'uuid1', name: 'existing-vm')
      @nutanix_cr.stubs(:vm_compute_attributes_for).with('uuid1').returns({ 'cpu' => 2 })

      @executor.stubs(:run_create).with(raise_if_recreate: true).raises(StandardError.new('update failed'))

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
