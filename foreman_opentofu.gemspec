require File.expand_path('lib/foreman_opentofu/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_opentofu'
  s.version     = ForemanOpentofu::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true' }
  s.license     = 'GPL-3.0-only'
  s.authors     = ['ATIX-AG']
  s.email       = ['info@atix.de']
  s.summary     = 'Plugin to provision host using opentofu'
  # also update locale/gemspec.rb
  s.description = 'Plugin to provision host using opentofu with different compute resources'

  s.files = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.required_ruby_version = '>= 2.7', '< 4'

  s.add_dependency 'deface', '< 2.0.0'
end
