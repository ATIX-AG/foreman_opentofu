module ForemanOpentofu
  module Renderer
    module Source
      class Snapshot < Foreman::Renderer::Source::Snapshot
        SNAPSHOTS_DIRECTORY = ForemanOpentofu::Engine.root.join('test', 'fixtures', 'renderer', 'snapshots')

        class << self
          def snapshot_path(template, suffix = 'host4dhcp')
            File.join(SNAPSHOTS_DIRECTORY, "#{template_path(template).tr(' ', '_')}.#{suffix}.snap.txt")
          end

          def hosts(template)
            ['empty', "#{template.name.split(' ').first.downcase}_host"]
          end
        end

        private

        def templates_directory
          ForemanOpentofu::TemplateSnapshotService::TEMPLATES_DIRECTORY
        end
      end
    end
  end
end
