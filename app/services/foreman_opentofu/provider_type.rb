module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes
    attr_accessor :capabilities

    def initialize(id)
      @id = id.to_sym
      @name = id.capitalize
      @capabilities = []
      @cr_attrs = []
    end

    def cr_attrs=(input)
      @cr_attrs = Array(input).map do |attr|
        ActiveSupport::HashWithIndifferentAccess.new(attr)
      end
    end

    # returns hash of available-attributes with attr-name as key
    def available_attributes
      raise "No available-attributes found for #{name}" unless attributes?

      attributes.index_by { |e| e['name'] }.with_indifferent_access
    end

    def attributes?
      @cr_attrs.present?
    end

    def attributes(group = nil)
      return nil if @cr_attrs.blank?

      return @cr_attrs if group.nil?

      @cr_attrs.select { |e| e['group'] == group }
    end
  end
end
