module ForemanOpentofu
  class ComputeVM
    include ActiveModel::Model
    include ActiveModel::Attributes

    def initialize(provider, attrs = {})
      @attributes = flatten_attrs(attrs.deep_stringify_keys)
      @provider = provider
      define_dynamic_readers!
    end

    def [](key)
      @attributes[key.to_s]
    end

    def to_h
      unwrap(@attributes.to_dup)
    end

    def power
      self['status'] || self['power'] || self['power_state']
    end

    # TODO: add definitions for different power on/off values
    def ready?
      power.to_s == 'on' || power.to_s == 'running'
    end

    def name
      self['name']
    end

    def persisted?
      self['identity'].present? || self['id'].present?
    end

    def start
      @provider.start_vm(name)
    end

    def stop
      @provider.stop_vm(name)
    end

    def reboot
      stop
      start
    end

    def reset
      reboot
    end

    def vm_ip_address
      @attributes['vm_ip_address']
    end

    def wait_for(&block)
      # TODO: I guess we have nothing to wait for
      # and we need to change the context of the given block
      instance_eval(&block)
    end

    def volumes_attributes
      vols_attrs = attribute_value('volumes_attributes')
      return vols_attrs if vols_attrs.is_a?(Hash)

      list = vols_attrs.presence || attribute_value('volumes')
      return {} if list.blank?

      Array(list).each_with_index.to_h { |vol, idx| [idx.to_s, vol] }
    end

    private

    def define_dynamic_readers!
      dynamic_attribute_keys.each do |key|
        next if respond_to?(key)

        define_singleton_method(key) do
          attribute_value(key)
        end
      end
    end

    def dynamic_attribute_keys
      @attributes.keys | provider_default_attributes.keys | provider_available_attribute_names
    end

    def provider_default_attributes
      return {} unless @provider.respond_to?(:default_attributes)

      @provider.default_attributes.to_h.deep_stringify_keys
    end

    def provider_available_attribute_names
      return [] unless @provider.respond_to?(:available_attributes)

      @provider.available_attributes.to_h.keys.map(&:to_s)
    rescue StandardError
      []
    end

    def attribute_value(key)
      key = key.to_s
      return @attributes[key] if @attributes.key?(key)

      provider_default_attributes[key]
    end

    def deep_wrap(value)
      case value
      when Hash
        value.transform_values { |v| deep_wrap(v) }
      when Array
        value.map { |v| deep_wrap(v) }
      else
        value
      end
    end

    def flatten_attrs(attrs)
      result = {}

      attrs.each do |key, value|
        if key.to_s == 'vm' && value.is_a?(Hash)
          # Merge the "vm" hash into the top-level
          result.merge!(value)
        else
          result[key] = value
        end
      end

      result
    end

    def respond_to_missing?(method_name, include_private = false)
      dynamic_attribute_keys.include?(method_name.to_s) || super
    end

    def method_missing(method_name, *args)
      return super unless args.empty?

      key = method_name.to_s
      return attribute_value(key) if dynamic_attribute_keys.include?(key)

      super
    end
  end
end
