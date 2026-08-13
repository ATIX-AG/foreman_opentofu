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
      @app_mock.stubs(:destroy).returns do
        ForemanOpentofu::TfState.find_by(uuid: 'uuid-1')&.destroy
      end
      @app_mock.stubs(:output).with('vm_attrs').returns('identity' => 'uuid-1')
    end

    let(:key_pair) { FactoryBot.create(:key_pair) }

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

    test '#run_create with_raise_if_recreate raises' do
      stub_opentofu_tmp_dir do
        @app_mock.expects(:show_plan).returns(
          {
            'resource_changes' => [
              {
                'change' => { 'actions' => %w[create delete] },
                'type' => 'anything',
                'address' => 'recreated',
              },
              {
                'change' => { 'actions' => ['update'] },
                'type' => 'something',
                'address' => 'updated',
              },
              {
                'type' => 'nothing',
                'address' => 'unchanged',
              },
              {},
            ],
          }
        )
        @compute_resource.tofu_provider.expects(:filter_resource_changes).with(
          [
            {
              'change' => { 'actions' => %w[create delete] },
              'type' => 'anything',
              'address' => 'recreated',
            },
          ]
        ).returns(
          [
            {
              'change' => { 'actions' => %w[create delete] },
              'type' => 'anything',
              'address' => 'recreated',
            },
          ]
        )

        assert_raises(RuntimeError) { @executor.run_create(raise_if_recreate: true) }
      end
    end

    test '#run_create with_raise_if_recreate passes' do
      stub_opentofu_tmp_dir do
        @app_mock.expects(:show_plan).returns(
          {
            'resource_changes' => [
              {
                'change' => { 'actions' => ['update'] },
                'type' => 'something',
                'address' => 'updated',
              },
              {
                'change' => { 'actions' => ['create'] },
                'type' => 'something',
                'address' => 'added',
              },
              {
                'change' => { 'actions' => ['delete'] },
                'type' => 'something',
                'address' => 'removed',
              },
              {
                'type' => 'nothing',
                'address' => 'unchanged',
              },
              {},
            ],
          }
        )
        @compute_resource.tofu_provider.expects(:filter_resource_changes).with([]).returns([])

        assert_not_nil @executor.run_create(raise_if_recreate: true)
      end
    end

    test '#run_create destroys created resources when apply fails' do
      stub_opentofu_tmp_dir do
        tf_state = FactoryBot.create(:tf_state, name: 'vm-1')
        failure = RuntimeError.new('apply failed')

        @app_mock.expects(:apply).raises(failure)
        @app_mock.expects(:destroy)

        error = assert_raises(RuntimeError) { @executor.run_create }
        assert_equal 'apply failed', error.message
        assert_nil ForemanOpentofu::TfState.find_by(id: tf_state.id)
      end
    end

    test '#run_create includes cleanup failure when destroy also fails' do
      stub_opentofu_tmp_dir do
        failure = RuntimeError.new('apply failed')

        @app_mock.expects(:apply).raises(failure)
        @app_mock.expects(:destroy).raises(RuntimeError.new('destroy failed'))
        Rails.logger.expects(:error).with(regexp_matches(/Removing OpenTofu resource after host create.*destroy failed/))

        error = assert_raises(RuntimeError) { @executor.run_create }
        assert_match(/apply failed/, error.message)
        assert_match(/Removing resource after failed host creation also failed: destroy failed/, error.message)
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

    test '#run_key resets ssh_keys cache' do
      @compute_resource.expects(:reset_cached_ssh_keys)
      stub_opentofu_tmp_dir do
        @executor.run_key key_pair do |tofu|
        end
      end
    end

    test '#run_key calls #run' do
      do_something = lambda do |tofu|
        assert_equal @app_mock, tofu
      end

      stub_opentofu_tmp_dir do
        @executor.run_key key_pair, &do_something
      end

      assert_equal key_pair.name, @executor.instance_variable_get('@host_name')
      assert @executor.instance_variable_get('@use_backend')
    end

    test '#run_create_key' do
      @executor.expects(:run_key)
      @executor.run_create_key(key_pair)
    end

    test '#run_destroy_key' do
      @executor.expects(:run_key)
      @executor.run_destroy_key(key_pair)
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

        @app_mock.expects(:output).with('resources').returns('something')
        assert_equal 'something', executor.run_fetch
      end
    end

    test '#key_pairs returns "Array"' do
      assert_kind_of Array, @executor.key_pairs
    end

    test '#key_pairs reads available ssh-keys' do
      @compute_resource.expects(:available_ssh_keys)
      @executor.key_pairs
    end
  end
end
