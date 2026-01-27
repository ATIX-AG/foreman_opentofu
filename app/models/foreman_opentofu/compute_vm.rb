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
      self['power'] || self['power_state']
    end

    # TODO: add definitions for different power on/off values
    def ready?
      power.to_s == 'on'
    end

    def name
      self['name']
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

    private

    def define_dynamic_readers!
      @attributes.each_key do |key|
        next if respond_to?(key)

        define_singleton_method(key) do
          @attributes[key]
        end
      end
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
      @attributes.key?(method_name.to_s) || super
    end

    def method_missing(method_name, *args)
      key = method_name.to_s
      return @attributes[key] if @attributes.key?(key)

      super
    end
  end
end
