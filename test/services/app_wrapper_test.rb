require 'test_plugin_helper'

module ForemanOpentofu
  class AppWrapperTest < ActiveSupport::TestCase
    let(:app_wrapper) do
      AppWrapper.new(
        File.join('/tmp', "app_wrapper_test_#{rand(9999).to_s.rjust(4, '0')}"),
        variables: {
          user: 'admin',
          password: 'secret',
        }
      )
    end

    def setup
      Dir.mkdir(app_wrapper.workdir)
    end

    def teardown
      Dir.each_child(app_wrapper.workdir) do |file|
        File.unlink(File.join(app_wrapper.workdir, file))
      end
      Dir.unlink(app_wrapper.workdir)
    end

    test 'params parsed' do
      params = app_wrapper.send(:parse_params, ['tofu', 'init', '--json'])
      assert_kind_of(Array, params)
      assert_equal(3, params.length)
      params = app_wrapper.send(:parse_params, '--json')
      assert_kind_of(Array, params)
      assert_equal(1, params.length)
    end

    test 'command is assembled' do
      cmdline = app_wrapper.send(:command, ['tofu', 'init', '--json'])
      assert_kind_of(String, cmdline)
      assert_equal("'tofu' 'init' '--json' 2>&1", cmdline)
    end

    test 'tofu_execute() adds default_params' do
      def_p = ['--always', '--added']
      base_c = 'none'
      app_wrapper.expects(:base_command).returns(base_c)
      app_wrapper.expects(:default_params).returns(def_p)
      app_wrapper.expects(:execute).with([base_c, 'noop'] + def_p)
      app_wrapper.send(:tofu_execute, 'noop')
    end

    test 'variables specified as envvars' do
      envvars = app_wrapper.send(:envvars)
      assert_empty(envvars.keys.reject { |var| var.starts_with?('TF_VAR_') })
      assert_equal 'secret', envvars['TF_VAR_password']
    end

    test 'create_variables_file()' do
      app_wrapper.create_variables_file
      expected = "variable \"user\" {\n  type = string\n  sensitive = false\n}"
      expected << "\nvariable \"password\" {\n  type = string\n  sensitive = true\n}"
      assert_equal expected, File.read(app_wrapper.vardeffile).strip
    end

    test 'init creates variable definition file' do
      app_wrapper.expects(:create_variables_file).once
      app_wrapper.expects(:tofu_execute)
      app_wrapper.init
    end
  end
end
