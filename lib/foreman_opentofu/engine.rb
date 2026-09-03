module ForemanOpentofu
  class Engine < ::Rails::Engine
    isolate_namespace ForemanOpentofu
    engine_name 'foreman_opentofu'

    # Add any db migrations
    initializer 'foreman_opentofu.load_app_instance_data' do |app|
      ForemanOpentofu::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end

      app.config.autoload_paths += Dir["#{config.root}/app/services/foreman_opentofu"]
    end

    initializer 'foreman_opentofu.register_plugin', before: :finisher_hook do |app|
      app.reloader.to_prepare do
        Foreman::Plugin.register :foreman_opentofu do
          requires_foreman '>= 3.0'
          register_gettext

          extend_template_helpers ForemanOpentofu::Concerns::BaseTemplateScopeExtensions
          # Add Global files for extending foreman-core components and routes
          # Register Nutanix compute resource in foreman
          compute_resource ForemanOpentofu::Tofu

          template_labels 'opentofu_script' => N_('OpenTofu Script template')

          settings do
            category :opentofu, N_('OpenTofu') do
              setting 'tfstate_token_timeout',
                type: :integer,
                default: 600,
                full_name: N_('TfState Token Timeout'),
                description: N_('Number of seconds a run of OpenTofu command is allowed to report TfState back to the plugin.')
              setting 'tofu_ssh_key_bits',
                type: :integer,
                default: 4096,
                full_name: N_('SSH-Key Length'),
                description: N_('Number of Bits for the SSH-Key required to provision hosts on image-based providers.')
            end
          end
        end
      end
    end

    config.autoload_paths << File.expand_path('../lib', __dir__)
    # Include concerns in this config.to_prepare block
    config.to_prepare do
      ::ComputeResourcesController.include ForemanOpentofu::Controller::Parameters::ComputeResource
      ::ComputeResourcesController.include ForemanOpentofu::ComputeResourcesController
      ::Api::V2::ComputeResourcesController.include ForemanOpentofu::Controller::Parameters::ComputeResource
      ::ComputeResourcesVmsController.include ForemanOpentofu::ComputeResourcesVmsController
      ::Host::Managed.include Orchestration::Tofu::Compute
      ::Authorizer.prepend ForemanOpentofu::AuthorizerPowerOverride unless ::Authorizer < ForemanOpentofu::AuthorizerPowerOverride
      ::HostsController.prepend ForemanOpentofu::HostsControllerPowerOverride unless ::HostsController < ForemanOpentofu::HostsControllerPowerOverride
      if defined?(::Api::V2::HostsController) && !(::Api::V2::HostsController < ForemanOpentofu::Api::V2::HostsControllerPowerOverride)
        ::Api::V2::HostsController.prepend ForemanOpentofu::Api::V2::HostsControllerPowerOverride
      end
    rescue StandardError => e
      Rails.logger.warn "ForemanOpentofu: skipping engine hook (#{e})"
    end

    load 'foreman_opentofu/provider_types.rb'

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanOpentofu::Engine.load_seed
      end
    end
  end
end
