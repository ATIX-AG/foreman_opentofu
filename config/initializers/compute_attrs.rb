require 'json'

CONFIG_DIR = File.expand_path(File.join(__dir__, '..'))

# rubocop:disable Style/MutableConstant
CR_ATTRS = {}
# rubocop:enable Style/MutableConstant

Dir["#{CONFIG_DIR}/*.{json,yaml,yml}"].each do |filename|
  next unless File.exist?(filename)

  file_content = File.read(filename)
  provider = File.basename(filename, '.*')
  CR_ATTRS[provider] = case File.extname(filename)
                       when /\.json/i then JSON.parse(file_content)
                       when /\.ya?ml/i then YAML.safe_load(file_content)
                       else next
                       end
end
