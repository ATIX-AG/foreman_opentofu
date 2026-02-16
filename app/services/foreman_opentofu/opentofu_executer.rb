require 'json'

module ForemanOpentofu
  class OpentofuExecuter
    def initialize(*args)
      @compute_resource = args[0]
      @cr_attrs = args[1] || {}
    end

    def run(mode = 'create')
      Dir.mktmpdir('opentofu_') do |dir|
        tofu = AppWrapper.new(dir)
        @use_backend = %w[create destroy output].include?(mode)
        tofu.main_configuration = render_template
        tofu.init
        run_mode(tofu, mode)
      end
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
