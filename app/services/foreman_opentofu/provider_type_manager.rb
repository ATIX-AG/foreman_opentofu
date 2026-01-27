module ForemanOpentofu
  class ProviderTypeManager
    @defined_provider_types = {}

    class << self
      private :new
      attr_reader :defined_provider_types

      # Plugin constructor
      def register(id, &block)
        defined_prov_type = find_defined(id)
        return if defined_prov_type.present?

        defined_prov_type = ::ForemanOpentofu::ProviderType.new(id)
        defined_prov_type.instance_eval(&block) if block_given?
        @defined_provider_types[id.to_s] = defined_prov_type
      end

      def find(provider_type)
        find_defined(provider_type)
      end

      def find_defined(provider_type)
        @defined_provider_types[provider_type.to_s]
      end

      def enabled_provider_type_names
        @defined_provider_types.values.map(&:name)
      end

      def enabled_provider_types
        @defined_provider_types.values
      end
    end
  end
end
