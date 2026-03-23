#
# This test tries to render all templates mentioned in snapshots.yaml
# and compares the result with copies in test/fixtures/renderer/snapshots.
# After review of changes, snapshots can be easily regenerated with:
#
#   bundle exec rake foreman_opentofu:snapshots:generate RAILS_ENV=test
#

require 'test_plugin_helper'

class RendererTest < ActiveSupport::TestCase
  setup do
    # don't advertise any plugins to prevent different results
    # TODO: Return only this Plugin, duh
    ::Foreman::Plugin.stubs(:find).returns(nil)

    @backup_setting_safemode_render = Setting[:safemode_render]

    # dns_query macro
    Resolv::DNS.any_instance.stubs(:getaddress).returns('127.0.0.15')
  end

  teardown do
    Setting[:safemode_render] = @backup_setting_safemode_render
  end

  context 'safe mode' do
    setup do
      Setting[:safemode_render] = true
    end

    ForemanOpentofu::TemplateSnapshotService.templates.each do |template|
      test "rendered #{template.name} template should match snapshots" do
        assert_template(template)
      end
    end
  end

  context 'unsafe mode' do
    setup do
      Setting[:safemode_render] = false
    end

    ForemanOpentofu::TemplateSnapshotService.templates.each do |template|
      test "rendered #{template.name} template should match snapshots" do
        assert_template(template)
      end
    end
  end

  private

  def assert_template(template)
    ForemanOpentofu::Renderer::Source::Snapshot.hosts(template).each do |host|
      snapshot_path = ForemanOpentofu::Renderer::Source::Snapshot.snapshot_path(template, host)
      rendered = ForemanOpentofu::TemplateSnapshotService.render_template(template, host)
      assert_equal File.read(snapshot_path), rendered, "Rendered template #{template.name} did not match the snapshot."
    end
  end
end
