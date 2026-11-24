require 'deface'

module ForemanOpentofu
  require 'foreman_opentofu/version'
  require 'foreman_opentofu/engine'

  OPENTOFU_MAIN_PATH = '/var/lib/foreman-opentofu'.freeze
  OPENTOFU_TMP_PATH = File.join(OPENTOFU_MAIN_PATH, 'tmp').freeze
  OPENTOFU_PLUGIN_CACHE_PATH = File.join(OPENTOFU_MAIN_PATH, 'plugin-cache').freeze
  OPENTOFU_CLI_CONFIG_PATH = '/etc/foreman/tofurc'.freeze
end
