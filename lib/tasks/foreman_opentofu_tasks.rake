require 'rake/testtask'

# Tasks
namespace :foreman_opentofu do
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop) do |task|
    # details are handled in .rubocop.yml
    task.patterns = [ForemanOpentofu::Engine.root.to_s]
  end
rescue LoadError => e
  raise e unless Rails.env.production?
end

# Tests
namespace :test do
  desc 'Test ForemanOpentofu'
  Rake::TestTask.new(:foreman_opentofu) do |t|
    test_dir = File.expand_path('../../test', __dir__)
    t.libs << 'test'
    t.libs << test_dir
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
    t.warning = false
  end
end

Rake::Task[:test].enhance ['test:foreman_opentofu']

load 'tasks/jenkins.rake'
Rake::Task['jenkins:unit'].enhance ['test:foreman_opentofu', 'foreman_opentofu:rubocop'] if Rake::Task.task_defined?(:'jenkins:unit')
