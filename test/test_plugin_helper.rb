# This calls the main test_helper in Foreman-core
require 'test_helper'

# Add plugin to FactoryBot's paths
FactoryBot.definition_file_paths << File.join(File.dirname(__FILE__), 'factories')
FactoryBot.reload

def assert_snapshot(obj, name, expected)
  path = ForemanOpentofu::Engine.root.join('test', 'fixtures', 'snapshots', obj.class.name.underscore, "#{name}.txt")

  assert_equal File.read(path).strip, expected.strip
end
