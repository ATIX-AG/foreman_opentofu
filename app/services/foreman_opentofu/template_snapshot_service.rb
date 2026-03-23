module ForemanOpentofu
  # < Foreman::TemplateSnapshotService
  class TemplateSnapshotService
    TEMPLATES_DIRECTORY = ForemanOpentofu::Engine.root.join('app', 'views', 'templates', 'provisioning')

    def self.templates
      new.templates
    end

    def self.render_template(template, host_name = :empty)
      raise 'TemplateSnapshotService can only be used in test environment' unless Rails.env.test?
      require 'factory_bot_rails'

      cr_attrs = new.send(host_name.to_sym)
      provider_type = template.name.split(' ').first.downcase
      variables = {
        compute_resource: FactoryBot.build("opentofu_#{provider_type}_cr".to_sym),
        cr_attrs: cr_attrs || {},
        use_backend: true,
        token: 'very_secret_token',
        host_name: host_name,
        resource: nil,
      }
      variables[:ssh_key] = variables[:compute_resource].key_pair if variables[:compute_resource].key_pair
      source = ForemanOpentofu::Renderer::Source::Snapshot.new(template)
      scope = Foreman::Renderer.get_scope(source: source, variables: variables)
      Foreman::Renderer::UnsafeModeRenderer.render(source, scope)
    end

    def templates
      files.map { |path| ForemanOpentofu::Renderer::Source::Snapshot.load_file(path) }
    end

    def hetzner_host
      {
        server_type: 'cx23',
      }
    end

    def nutanix_host
      {
        'cluster_uuid' => 'my_cluster_uuid',
        'volumes_attributes' => [
          {
            size_gb: 40,
            container_uuid: 'my_container_uuid',
          },
        ],
        'interfaces_attributes' => [
          {
            model: 'E1000',
            subnet_uuid: 'my_subnet_uuid',
          },
        ],
      }
    end

    def empty
      {}
    end

    private

    def files
      @files ||= YAML.safe_load_file(ForemanOpentofu::Engine.root.join('test', 'fixtures', 'renderer', 'snapshots.yaml')).fetch('files', []).map { |path| File.join(TEMPLATES_DIRECTORY, path) }
    end
  end
end
