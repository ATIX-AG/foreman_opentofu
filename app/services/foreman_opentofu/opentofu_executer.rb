require 'json'

module ForemanOpentofu
  class OpentofuExecuter
    def initialize(compute_resource, args = {})
      @compute_resource = compute_resource
      @cr_attrs = args.to_h
      @resource = @cr_attrs['resource']
      @host_name = @cr_attrs['name'] || 'test'
    end

    def run(mode = '')
      Dir.mktmpdir('opentofu_') do |dir|
        tofu = AppWrapper.new(dir)
        @use_backend = %w[create destroy output].include?(mode)
        @token = create_token(@host_name) if @use_backend
        tofu.main_configuration = render_template
        tofu.init
        yield(tofu)
      end
    end

    # creates a new authentication token for the TfState API-controller
    # needed for tofu command to send it's state-file to the database.
    # returns the created token
    def create_token(host_name)
      new_token = nil
      # This construct makes sure the token is created outside of the current transaction
      # which is necessary for the API-controller to check the token, while the current transaction still runs
      # see https://stackoverflow.com/a/11675647
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          token = ForemanOpentofu::Token.find_or_create_by(name: host_name)
          new_token = if token.expired?
                        token.generate
                      else
                        token.token
                      end
        end
      end.join
      new_token
    end

    def run_new
      run('new') do |tofu|
        tofu.plan
        tofu.show_plan
      end
    end

    def run_test_connection
      run('test', &:plan)
    end

    def run_create
      run('create') do |tofu|
        tofu.apply
        attrs = tofu.output('vm_attrs')
        ForemanOpentofu::TfState.find_by(name: @cr_attrs['name'])&.update(uuid: attrs['identity'])
        attrs
      end
    end

    def run_output
      run('output') do |tofu|
        tofu.output('vm_attrs')
      end
    end

    def run_destroy
      run('destroy', &:destroy)
    end

    def run_fetch
      run do |tofu|
        tofu.apply
        tofu.output('resources')
      end
    end

    private

    def render_template
      template = provision_template
      scope = Foreman::Renderer.get_scope(source: template)
      source = Foreman::Renderer.get_source(template: template)
      scope.instance_variable_set(:@compute_resource, @compute_resource)
      scope.instance_variable_set(:@cr_attrs, @cr_attrs) if @cr_attrs
      scope.instance_variable_set(:@use_backend, @use_backend)
      scope.instance_variable_set(:@token, @token) if @use_backend
      scope.instance_variable_set(:@host_name, @host_name)
      scope.instance_variable_set(:@resource, @resource)
      rendered_template = Foreman::Renderer::UnsafeModeRenderer.render(source, scope)
      raise ::Foreman::Exception, N_('Unable to render provisioning template') unless rendered_template

      rendered_template
    end

    def provision_template
      name = @compute_resource.opentofu_template.name
      template = ProvisioningTemplate.unscoped.find_by(name: name)
      unless template
        raise ::Foreman::Exception.new(N_('Unable to find template specified by %s setting'),
          name)
      end

      template
    end
  end
end
