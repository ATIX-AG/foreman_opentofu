module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes

    def initialize(id)
      @id = id.to_sym
      @name = id.capitalize
    end

    # returns hash of available-attributes with attr-name as key
    def available_attributes
      raise "No available-attributes found for #{name}" unless attributes?

      attributes&.index_by { |e| e['name'] }
    end

    def attributes?
      CR_ATTRS.key? id.to_s
    end

    def attributes(group = nil)
      return nil unless CR_ATTRS.key? id.to_s

      a = CR_ATTRS[id.to_s]
      return a if group.nil?

      a.select { |e| e['group'] == group }
    end
  end
end
