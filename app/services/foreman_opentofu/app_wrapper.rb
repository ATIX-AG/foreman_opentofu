module ForemanOpentofu
  class AppWrapper
    include HclFormat
    attr_reader :workdir

    # TODO: for future versions
    #   - manage temp-work-dir; problem: no auto-remove after finished :-(
    #   - handle ENVVars if applicable
    #   - handle stderr and stdout separately
    #   - use JSON-output for easier parsing
    #   - do we need locking or has the object be atomic

    def initialize(workdir, opts = {})
      @workdir = workdir
      @variables = opts[:variables]
    end

    # rubocop:disable Style/SingleLineMethods
    def planfile()   File.join(workdir, 'plan.bin')     end
    def conffile()   File.join(workdir, 'main.tf')      end
    def vardeffile() File.join(workdir, 'variables.tf') end

    def base_command() 'tofu' end
    # rubocop:enable Style/SingleLineMethods

    # write variables definition file based on @variables into 'variables.tf'
    def create_variables_file
      File.open(vardeffile, 'w') do |f|
        @variables.each_key do |var|
          data = { 'type' => :string }
          data['sensitive'] = var.to_s == 'password'

          f << block_to_hcl(['variable', var], data)
        end
      end
    end

    def variable_params
      @variables.map { |var, val| ['-var', "#{var}=#{val}"] }.flatten
    end

    def default_params
      [
        '-no-color',
      ]
    end

    # optional: specify block to access command-pipe (object of class `IO`), e.g.
    # tofu.init do |t|
    #   until t.eof? do
    #     puts("Message from Tofu: #{t.gets}")
    #   end
    # end
    def init(params = [], &block)
      create_variables_file if @variables

      tofu_execute('init', ['-input=false'].concat(parse_params(params)), &block)
    end

    def plan(params = [])
      tofu_execute('plan', ["-out=#{planfile}"].concat(parse_params(params)))
    end

    def apply(params = [])
      tofu_execute('apply', ['-auto-approve'].concat(parse_params(params)))
    end

    def destroy(params = [])
      tofu_execute('destroy', ['-auto-approve'].concat(parse_params(params)))
    end

    def output(params = [])
      JSON.parse(tofu_execute('output', ['-json'].concat(parse_params(params))))
    end

    # TODO: find better name ;-)
    def show_plan(params = [])
      JSON.parse(tofu_execute('show', ['-json', planfile].concat(parse_params(params))))
    end

    def main_configuration
      File.read(conffile)
    end

    def main_configuration=(config)
      File.write(conffile, config)
    end

    private

    def parse_params(params)
      params.is_a?(String) ? [params] : params
    end

    def tofu_execute(action, params = [], &block)
      execute [base_command, action].concat(default_params).concat(params), &block
    end

    def command(cmd)
      cmd.map { |item| "'#{item}'" }.append('2>&1').join(' ')
    end

    def common_envvars
      {
        'TF_PLUGIN_CACHE_DIR' => ForemanOpentofu::OPENTOFU_PLUGIN_CACHE_PATH,
        'TEMPDIR' => ForemanOpentofu::OPENTOFU_TMP_PATH,
        'TMPDIR' => ForemanOpentofu::OPENTOFU_TMP_PATH,
        'TMP' => ForemanOpentofu::OPENTOFU_TMP_PATH,
        'TEMP' => ForemanOpentofu::OPENTOFU_TMP_PATH,
      }
    end

    def terraform_envvars
      @variables.transform_keys { |variable| "TF_VAR_#{variable}" }
    end

    def envvars
      common_envvars.merge(terraform_envvars)
    end

    def execute(cmd)
      output = nil
      # quote cmdline parameters and add stderr to stdout
      commandline = command(cmd)
      IO.popen(envvars, commandline, 'r+', chdir: workdir) do |pipe|
        if block_given?
          yield pipe
        else
          output = pipe.read
        end
      end
      ret = $CHILD_STATUS
      Rails.logger.info "#{cmd} returned #{ret.inspect}"
      Rails.logger.debug output.to_s
      unless ret.success?
        Rails.logger.error "Command failed with output: #{output}"
        # TODO: do we need to use a specific exception-type here?
        raise "command failed with code #{ret.exitstatus}:\n#{output}"
      end

      output
    end
  end
end
