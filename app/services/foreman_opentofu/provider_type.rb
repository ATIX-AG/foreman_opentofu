module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes
    attr_accessor :capabilities

    def initialize(id)
      @id = id.to_sym
      @name = id.capitalize
      @capabilities = [:build]
      @provider_attrs = []
    end

    def provider_attrs=(input)
      @provider_attrs = Array(input).map do |attr|
        ActiveSupport::HashWithIndifferentAccess.new(attr)
      end
    end

    # if necessary, select-parameter named 'available_images' must be specified!
    def available_images(compute_resource)
      attribute = find_attr_by('name', 'available_images')
      raise NotImplementedError if attribute.nil?

      query_opts = attribute['options']
      case query_opts
      when nil then raise NotImplementedError
      # TODO: Check if Array really works!
      when Array then query_opts
      when Hash then compute_resource.available_resource(query_opts.dig('data_source', 'name'), query_opts)
      else raise 'available_images in ProviderType config is of unknown type.'
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
      return [] unless attributes?

      return @provider_attrs if group.nil?

      @provider_attrs.select { |e| e['group'] == group }
    end

    # return Array of Hashes of all attributes that have `key` set to `value`.
    # Optional: limited to `group`
    def search_attr_by(key, value, group = nil)
      attributes(group).select { |attr| attr[key] == value }
    end

    # return Hash of attribute that has `key` set to `value`.
    # If multiple exists, first in list is returned
    # Returns `nil` if none is found
    # Optional: limited to `group`
    def find_attr_by(key, value, group = nil)
      search_attr_by(key, value, group).first
    end

    def provided_attributes
      # TODO: maybe we need to do something more sophisticated, here.
      #       network-based deployment needs MAC to set-up DHCP, but
      #       on image-based deployment we usually only get IPv4/6-address
      { mac: :mac }
    end
  end
end
