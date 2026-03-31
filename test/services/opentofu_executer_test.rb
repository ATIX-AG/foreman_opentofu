require 'test_helper'
require 'minitest/stub_const'

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
      @app_mock.stubs(:destroy).returns do
        ForemanOpentofu::TfState.find_by(uuid: 'uuid-1')&.destroy
      end
      @app_mock.stubs(:output).with('vm_attrs').returns('identity' => 'uuid-1')
    end

    # Could not add this stub in setup as it would then try to automatically run
    # remove_const to remove the stub_const afterwards and this method does not exist
    def stub_opentofu_tmp_dir(&block)
      ForemanOpentofu.stub_const(:OPENTOFU_TMP_PATH, '/tmp/', &block)
    end

    test '#run create updates tf_state and returns attrs' do
      stub_opentofu_tmp_dir do
        tf_state = FactoryBot.create(:tf_state, name: 'vm-1')
        result = @executor.run_create
        tf_state.reload
        assert_equal tf_state.uuid, result['identity']
        assert_not_nil tf_state.uuid, 'tf_state UUID should be set'
      end
    end

    test '#run output returns vm_attrs' do
      stub_opentofu_tmp_dir do
        result = @executor.run_output
        assert_equal 'uuid-1', result['identity']
      end
    end

    test '#run destroy calls destroy' do
      stub_opentofu_tmp_dir do
        @executor.run_destroy
        assert_nil ForemanOpentofu::TfState.find_by(uuid: 'uuid-1')
      end
    end

    test '#run new calls plan and show_plan' do
      stub_opentofu_tmp_dir do
        @app_mock.expects(:plan)
        @app_mock.expects(:show_plan)
        @executor.run_new
      end
    end

    test '#run test_connection only plans' do
      stub_opentofu_tmp_dir do
        @app_mock.expects(:plan)
        @executor.run_test_connection
      end
    end

    test '#run creates user_data file' do
      stub_opentofu_tmp_dir do
        executor = OpentofuExecuter.new(@compute_resource, { 'user_data' => 'HelloWorld' })
        executor.expects(:render_template)
        file_mock = Minitest::Mock.new
        file_mock.expect(:write, nil, ['HelloWorld'])
        File.stub(:open, [], file_mock) do
          executor.run do |_tofu|
          end
        end
        file_mock.verify
      end
    end

    test '#render_template raises exception if nil returned' do
      stub_opentofu_tmp_dir do
        Foreman::Renderer::UnsafeModeRenderer.stubs(:render).returns(nil)
        assert_raises(Foreman::Exception) { @executor.send(:render_template, 'create') }
      end
    end

    test 'render_template with resource' do
      stub_opentofu_tmp_dir do
        executor = OpentofuExecuter.new(@compute_resource, { 'resource' => { name: 'datasource_name1', options: {} } })
        executor.stubs(:provision_template).returns(@template)

        @app_mock.expects(:output).with('resources')
        executor.run_fetch
      end
    end
  end
end
