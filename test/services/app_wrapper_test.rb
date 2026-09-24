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

    context '#error_summary' do
      test 'extracts error summaries and details and excludes progress and warnings' do
        output = [
          { type: 'apply_start', '@message': 'Creating resources...' },
          { type: 'diagnostic', diagnostic: { severity: 'error', summary: "First failure\ncontinued summary", detail: 'Source details' } },
          { type: 'diagnostic', diagnostic: { severity: 'warning', summary: 'Deprecated option' } },
          { type: 'diagnostic', diagnostic: { severity: 'error', summary: 'Second failure' } },
        ].map(&:to_json).join("\n")

        assert_equal "Error: First failure\ncontinued summary\nSource details\n\nError: Second failure",
          app_wrapper.send(:error_summary, output)
      end

      test 'extracts diagnostics despite non-JSON lines and unrelated JSON values' do
        output = [
          'Startup message',
          'null',
          '[]',
          '42',
          '{}',
          '{invalid json',
          { type: 'diagnostic', diagnostic: nil }.to_json,
          { type: 'diagnostic', diagnostic: { severity: 'error' } }.to_json,
          { type: 'diagnostic', diagnostic: { severity: 'error', summary: 'Permission denied' } }.to_json,
        ].join("\n")

        assert_equal 'Error: Permission denied', app_wrapper.send(:error_summary, output)
      end

      test 'preserves JSON output without an error diagnostic' do
        output = { type: 'diagnostic', diagnostic: { severity: 'warning', summary: 'Deprecated option' } }.to_json

        assert_equal output, app_wrapper.send(:error_summary, output)
      end

      test 'preserves output without an error diagnostic' do
        output = "Command failed\nConnection refused"

        assert_equal output, app_wrapper.send(:error_summary, output)
      end
    end

    test 'failed commands raise summaries and log readable and raw output' do
      output = { type: 'diagnostic', '@message': 'Error: Permission denied', diagnostic: { severity: 'error', summary: 'Permission denied', detail: 'Access forbidden' } }.to_json
      File.write(File.join(app_wrapper.workdir, 'error.json'), output)
      Rails.logger.expects(:debug).with(output)
      Rails.logger.expects(:error).with("Command failed with output: Error: Permission denied\nAccess forbidden")

      error = assert_raises(RuntimeError) do
        app_wrapper.send(:execute, ['sh', '-c', 'cat error.json; exit 1'])
      end

      assert_equal "Error: Permission denied\nAccess forbidden", error.message
    end

    test 'failed apply logs fixture events and raises only the error diagnostic' do
      output = File.read(ForemanOpentofu::Engine.root.join('test', 'fixtures', 'foreman_opentofu', 'app_wrapper', 'apply_error.jsonl'))
      readable = <<~TEXT.chomp
        OpenTofu 1.12.6
        hcloud_server.node1: Plan to create
        hcloud_volume.volumes["0"]: Plan to create
        hcloud_server.node1: Creating...
        hcloud_server.node1: Creation complete after 24s [id=SERVER_ID]
        hcloud_volume.volumes["0"]: Creating...
        hcloud_volume.volumes["0"]: Creation errored after 0s
        Warning: Value derived from a deprecated source
        Unused attribute, consider removing it from your configuration.
        Error: invalid input in field 'size': Must be between 10 and 10240.
      TEXT
      File.write(File.join(app_wrapper.workdir, 'error.jsonl'), output)
      Rails.logger.expects(:debug).with(output)
      Rails.logger.expects(:error).with("Command failed with output: #{readable}")

      error = assert_raises(RuntimeError) do
        app_wrapper.send(:execute, ['sh', '-c', 'cat error.jsonl; exit 1'])
      end

      assert_equal "Error: invalid input in field 'size': Must be between 10 and 10240.", error.message
    end

    test 'successful commands log readable events and preserve raw output' do
      output = [
        { type: 'apply_start', '@message': 'Creating resources...' },
        { type: 'diagnostic', '@message': 'Warning: Deprecated option', diagnostic: { severity: 'warning', detail: 'Use the replacement' } },
        { type: 'diagnostic', '@message': 'Warning without detail', diagnostic: { severity: 'warning' } },
      ].map(&:to_json).join("\n")
      File.write(File.join(app_wrapper.workdir, 'output.json'), output)
      Rails.logger.expects(:debug).with(output)
      Rails.logger.expects(:info).with(regexp_matches(/returned/))
      Rails.logger.expects(:info).with("Creating resources...\nWarning: Deprecated option\nUse the replacement\nWarning without detail")

      assert_equal output, app_wrapper.send(:execute, ['cat', 'output.json'])
    end

    test 'logs use configured parameter filters while returned output keeps original values' do
      json = { variables: { password: { value: 'secret' }, user: { value: 'admin' }, missing: {}, invalid: nil }, format_version: '1.0' }
      output = JSON.pretty_generate(json)
      File.write(File.join(app_wrapper.workdir, 'variables.json'), output)
      redacted = { variables: { password: '[FILTERED]', user: { value: '[FILTERED]' }, missing: {}, invalid: nil }, format_version: '1.0' }.to_json
      Rails.logger.expects(:debug).with(redacted)
      Rails.logger.expects(:info).with(regexp_matches(/returned/))
      Rails.logger.expects(:info).with(redacted)

      assert_equal output, app_wrapper.send(:execute, ['cat', 'variables.json'])
    end

    test 'failed commands filter passwords in logs while preserving the original error output' do
      output = { variables: { password: { value: 'secret' } } }.to_json
      redacted = { variables: { password: '[FILTERED]' } }.to_json
      File.write(File.join(app_wrapper.workdir, 'error.json'), output)
      Rails.logger.expects(:debug).with(redacted)
      Rails.logger.expects(:error).with("Command failed with output: #{redacted}")

      error = assert_raises(RuntimeError) do
        app_wrapper.send(:execute, ['sh', '-c', 'cat error.json; exit 1'])
      end

      assert_equal output, error.message
    end

    test 'filters the password in mixed JSON lines and plain text' do
      output = "Startup message\n#{{ variables: { password: { value: 'secret' } } }.to_json}\nnull\n{invalid json\n"
      expected = "Startup message\n#{{ variables: { password: '[FILTERED]' } }.to_json}\nnull\n{invalid json\n"

      assert_equal expected, app_wrapper.send(:filter_sensitive_output, output)
    end

    test 'readable output preserves plain text and unrelated JSON lines' do
      output = "Startup failure\n{invalid json\nnull\n[]\n42\n{}\n"

      assert_equal output.chomp, app_wrapper.send(:readable_output, output)
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
      assert_equal 'secret', envvars['TF_VAR_password']
    end

    test 'terraform variables all start with TF_VAR_' do
      terraform_envvars = app_wrapper.send(:terraform_envvars)
      assert_empty(terraform_envvars.keys.reject { |var| var.starts_with?('TF_VAR_') })
    end

    test 'common variables as envvars' do
      envvars = app_wrapper.send(:envvars)
      assert_equal ForemanOpentofu::OPENTOFU_PLUGIN_CACHE_PATH, envvars['TF_PLUGIN_CACHE_DIR']
      %w[TEMPDIR TMPDIR TMP TEMP].each do |var|
        assert_equal ForemanOpentofu::OPENTOFU_TMP_PATH, envvars[var]
      end
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

    test 'plan requests JSON events and saves the plan' do
      app_wrapper.expects(:tofu_execute).with('plan', ["-out=#{app_wrapper.planfile}", '-input=false'])

      app_wrapper.plan('-input=false')
    end

    test 'destroy requests JSON events and auto approval' do
      app_wrapper.expects(:tofu_execute).with('destroy', ['-auto-approve', '-input=false'])

      app_wrapper.destroy('-input=false')
    end

    context 'apply()' do
      test 'executes with -auto-approve' do
        app_wrapper.expects(:tofu_execute).with('apply', ['-auto-approve'])

        app_wrapper.apply
      end

      test 'uses plan-file, if present' do
        FileUtils.touch app_wrapper.planfile
        app_wrapper.expects(:tofu_execute).with('apply', ['-auto-approve', app_wrapper.planfile])

        app_wrapper.apply
      end

      test 'accepts additional parameters Array' do
        FileUtils.touch app_wrapper.planfile
        app_wrapper.expects(:tofu_execute).with('apply', ['-auto-approve', '-input=false', '-no-color', app_wrapper.planfile])

        app_wrapper.apply(['-input=false', '-no-color'])
      end

      test 'accepts additional parameters String' do
        FileUtils.touch app_wrapper.planfile
        app_wrapper.expects(:tofu_execute).with('apply', ['-auto-approve', '-no-color', app_wrapper.planfile])

        app_wrapper.apply('-no-color')
      end
    end
  end
end
