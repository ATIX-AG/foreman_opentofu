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
          settings do
            category :opentofu, N_('Opentofu') do
              templates = lambda {
                Hash[ProvisioningTemplate.where(template_kind: TemplateKind.where(name: 'script')).map do |temp|
                       [temp[:name], temp[:name]]
                     end ]
              }

              setting 'provision_nutanix_host_template',
                type: :string,
                collection: templates,
                default: 'Nutanix provision - host',
                full_name: N_('Nutanix Host provision template'),
                description: N_('Opentofu script template to use for Nutanix based host provisioning')
              setting 'provision_ovirt_host_template',
                type: :string,
                collection: templates,
                default: 'Ovirt provision - host',
                full_name: N_('Ovirt Host provision template'),
                description: N_('Opentofu script template to use for Ovirt based host provisioning')
              setting 'provision_vsphere_host_template',
                type: :string,
                collection: templates,
                default: 'Vsphere provision - host',
                full_name: N_('Vsphere Host provision template'),
                description: N_('Opentofu script template to use for Vsphere based host provisioning')
            end
          end
        end
      end
    end

    config.autoload_paths << File.expand_path('../lib', __dir__)
    # Include concerns in this config.to_prepare block
    config.to_prepare do
      ::ComputeResourcesController.include ForemanOpentofu::Controller::Parameters::ComputeResource
      ::ComputeResourcesVmsController.include ForemanOpentofu::ComputeResourcesVmsController
      ::Host::Managed.include Orchestration::Tofu::Compute
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
