module ForemanOpentofu
  class AppWrapper
    attr_reader :workdir, :planfile, :conffile

    # TODO: for future versions
    #   - manage temp-work-dir; problem: no auto-remove after finished :-(
    #   - handle ENVVars if applicable
    #   - handle stderr and stdout separately
    #   - use JSON-output for easier parsing
    #   - do we need locking or has the object be atomic

    def initialize(workdir)
      @workdir = workdir
      @planfile = File.join(workdir, 'plan.bin')
      @conffile = File.join(workdir, 'main.tf')
    end

    def base_command
      'tofu'
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

    def execute(cmd)
      output = nil
      # quote cmdline parameters and add stderr to stdout
      commandline = command(cmd)
      Dir.chdir(workdir) do
        Rails.logger.debug "Start command: #{commandline.inspect}"
        IO.popen(commandline, 'r+') do |pipe|
          if block_given?
            yield pipe
          else
            output = pipe.read
          end
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
