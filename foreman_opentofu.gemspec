require File.expand_path('lib/foreman_opentofu/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_opentofu'
  s.version     = ForemanOpentofu::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true' }
  s.license     = 'GPL-3.0'
  s.authors     = ['Manisha Singhal']
  s.email       = ['singhal@atix']
  s.summary     = 'Plugin to provision host using opentofu'
  # also update locale/gemspec.rb
  s.description = 'Plugin to provision host using opentofu with different compute resources'

  s.files = Dir['{app,config,db,lib,locale,webpack}/**/*'] + ['LICENSE', 'package.json', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.required_ruby_version = '>= 2.7', '< 4'

  s.add_development_dependency 'rdoc'
  s.add_dependency 'deface'
end
