namespace :foreman_opentofu do
  namespace :snapshots do
    desc 'Generate snapshots'
    task generate: :environment do
      unless Rails.env.test?
        puts 'This task can only be run in test environment'
        exit
      end

      require 'database_cleaner'
      require 'factory_bot_rails'

      # Add plugin to FactoryBot's paths
      FactoryBot.definition_file_paths << ForemanOpentofu::Engine.root.join('test', 'factories')
      FactoryBot.reload

      module BaseMacrosStub
        def dns_lookup(_name_or_ip)
          'foreman.example.com'
        end
      end

      # ::Foreman::Plugin.singleton_class.send :prepend, PluginSnapshotStub
      ::Foreman::Renderer::Scope::Base.prepend BaseMacrosStub

      # clean the snapshot directory in order to delete renamed ones and keep it clean
      FileUtils.rm_rf(Dir.glob(File.join(
        ::ForemanOpentofu::Renderer::Source::Snapshot::SNAPSHOTS_DIRECTORY, '*'
      )))

      DatabaseCleaner.cleaning do
        Foreman.settings.load
        Setting[:foreman_url] = 'http://foreman.example.com'

        User.current = FactoryBot.build(:user, :admin)
        admin = FactoryBot.create(:user, :admin, password: 'password123', auth_source: FactoryBot.create(:auth_source_ldap))

        failed_snapshots = []

        User.as(admin.login) do
          ForemanOpentofu::TemplateSnapshotService.templates.each do |template|
            ForemanOpentofu::Renderer::Source::Snapshot.hosts(template).each do |host|
              snapshot_path = ForemanOpentofu::Renderer::Source::Snapshot.snapshot_path(template, host)
              dir = File.dirname(snapshot_path)
              FileUtils.mkdir_p(dir) unless File.directory?(dir)

              begin
                snapshot = ForemanOpentofu::TemplateSnapshotService.render_template(template, host)
                puts "Writing #{snapshot_path}"
                File.write(snapshot_path, snapshot)
              rescue StandardError => e
                warn "Snapshot #{snapshot_path} failed with #{e}"
                failed_snapshots << snapshot_path
              end
            end
          end
        end

        raise "#{failed_snapshots.count} snapshots failed generation or validation. Please inspect the output to see the details." unless failed_snapshots.empty?
      end
    end
  end
end
