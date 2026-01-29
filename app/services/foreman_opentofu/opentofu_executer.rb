require 'json'

module ForemanOpentofu
  class OpentofuExecuter
    def initialize(*args)
      @compute_resource = args[0]
      @cr_attrs = args[1] || {}
      @host_name = @cr_attrs['name'] || 'test'
    end

    def run(mode = 'create')
      Dir.mktmpdir('opentofu_') do |dir|
        tofu = AppWrapper.new(dir)
        @use_backend = %w[create destroy output].include?(mode)
        @token = create_token(@host_name) if @use_backend
        tofu.main_configuration = render_template
        tofu.init
        run_mode(tofu, mode)
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
          ForemanOpentofu::Token.find_or_create_by(name: host_name) do |token|
            new_token = token.generate_token
          end
        end
      end.join
      new_token
    end

    def run_mode(tofu, mode = 'new')
      @use_backend = true
      case mode
      when 'new'
        tofu.plan
        tofu.show_plan
      when 'test_connection'
        tofu.plan
      when 'create'
        tofu.plan
        tofu.apply
        attrs = tofu.output('vm_attrs')
        ForemanOpentofu::TfState.find_by(name: @cr_attrs['name'])&.update(uuid: attrs['identity'])
        attrs
      when 'output'
        tofu.output('vm_attrs')
      when 'destroy'
        tofu.destroy
      else
        raise "Please select one of the modes: 'new', 'test_connection', 'create' or 'destroy'"
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
      rendered_template = Foreman::Renderer::UnsafeModeRenderer.render(source, scope)
      raise ::Foreman::Exception, N_('Unable to render provisioning template') unless rendered_template

      rendered_template
    end

    def provision_template
      name = ''
      provider = @compute_resource.opentofu_provider
      case provider
      when 'nutanix'
        name = Setting[:provision_nutanix_host_template]
      when 'ovirt'
        name = Setting[:provision_ovirt_host_template]
      when 'vsphere'
        name = Setting[:provision_vsphere_host_template]
      end
      template = ProvisioningTemplate.unscoped.find_by(name: name)
      unless template
        raise ::Foreman::Exception.new(N_('Unable to find template specified by %s setting'),
          name)
      end

      template
    end
  end
end
