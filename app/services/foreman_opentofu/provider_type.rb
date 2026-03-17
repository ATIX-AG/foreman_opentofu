module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes
    attr_accessor :capabilities

    def initialize(id)
      @id = id.to_sym
      @name = id.capitalize
      @capabilities = []
      @provider_attrs = []
    end

    def provider_attrs=(input)
      @provider_attrs = Array(input).map do |attr|
        ActiveSupport::HashWithIndifferentAccess.new(attr)
      end
    end

    # returns hash of available-attributes with attr-name as key
    def available_attributes
      raise "No available-attributes found for #{name}" unless attributes?

      attributes.index_by { |e| e['name'] }.with_indifferent_access
    end

    def attributes?
      @provider_attrs.present?
    end

    def attributes(group = nil)
      return nil if @provider_attrs.blank?

      return @provider_attrs if group.nil?

      @provider_attrs.select { |e| e['group'] == group }
    end
  end
end
