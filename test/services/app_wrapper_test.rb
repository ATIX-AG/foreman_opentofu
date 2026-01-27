require 'test_plugin_helper'

module ForemanOpentofu
  class AppWrapperTest < ActiveSupport::TestCase
    let(:app_wrapper) { AppWrapper.new('/tmp') }

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
  end
end
