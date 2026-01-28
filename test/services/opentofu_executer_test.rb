require 'test_helper'

module ForemanOpentofu
  class OpentofuExecuterTest < ActiveSupport::TestCase
    setup do
      @compute_resource = FactoryBot.build_stubbed(:opentofu_nutanix_cr)
      @cr_attrs = { 'name' => 'vm-1' }
      @executor = OpentofuExecuter.new(@compute_resource, @cr_attrs)

      @template = FactoryBot.create(:provisioning_template, name: 'Nutanix test script')
      @executor.stubs(:provision_template).returns(@template)

      @app_mock = mock('AppWrapper')
      AppWrapper.stubs(:new).returns(@app_mock)
      @app_mock.stubs(:main_configuration=)
      @app_mock.stubs(:init)
      @app_mock.stubs(:plan)
      @app_mock.stubs(:show_plan)
      @app_mock.stubs(:apply)
      @app_mock.stubs(:destroy).returns { ForemanOpentofu::TfState.find_by(uuid: 'uuid-1')&.destroy }
      @app_mock.stubs(:output).with('vm_attrs').returns('identity' => 'uuid-1')
    end

    test '#run create updates tf_state and returns attrs' do
      tf_state = FactoryBot.create(:tf_state, name: 'vm-1')
      result = @executor.run('create')
      tf_state.reload
      assert_equal tf_state.uuid, result['identity']
      assert_not_nil tf_state.uuid, 'tf_state UUID should be set'
    end

    test '#run output returns vm_attrs' do
      result = @executor.run('output')
      assert_equal 'uuid-1', result['identity']
    end

    test '#run destroy calls destroy' do
      @executor.run('destroy')
      assert_nil ForemanOpentofu::TfState.find_by(uuid: 'uuid-1')
    end

    test '#run new calls plan and show_plan' do
      @app_mock.expects(:plan)
      @app_mock.expects(:show_plan)
      @executor.run('new')
    end

    test '#run test_connection only plans' do
      @app_mock.expects(:plan)
      @executor.run('test_connection')
    end

    test '#run with invalid mode raises RuntimeError' do
      assert_raises(RuntimeError) { @executor.run('invalid_mode') }
    end

    test '#render_template raises exception if nil returned' do
      Foreman::Renderer::UnsafeModeRenderer.stubs(:render).returns(nil)
      assert_raises(Foreman::Exception) { @executor.send(:render_template) }
    end
  end
end
