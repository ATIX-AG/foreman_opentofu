module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes, :default_interfaces, :default_volumes
    attr_accessor :capabilities, :disk_renderer, :nic_renderer,
      :recreate_type_allow_list

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

    # if necessary, select-parameter named 'available_ssh_keys' must be specified!
    def available_ssh_keys(compute_resource)
      attribute = find_attr_by('name', 'available_ssh_keys')
      return [] if attribute.nil? || attribute['options'].nil?

      query_opts = attribute['options']
      case query_opts
      when Hash then compute_resource.available_resource(query_opts.dig('data_source', 'name'), query_opts)
      else raise 'available_ssh_keys in ProviderType config is of unknown type.'
      end
    end

    def reset_cached_ssh_keys(compute_resource)
      attribute = find_attr_by('name', 'available_ssh_keys')
      return if attribute.nil? || attribute['options'].nil?

      query_opts = attribute['options']
      return unless query_opts.is_a? Hash

      compute_resource.cache_delete(query_opts.dig('data_source', 'name'))
    end

    # returns hash of available-attributes with attr-name as key
    def available_attributes(group = nil)
      raise "No available-attributes found for #{name}" unless attributes?

      attributes(group).index_by { |e| e['name'] }.with_indifferent_access
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

    def render_disk(disk, context, *args)
      return '' unless disk_renderer
      context.instance_exec(disk, *args, &disk_renderer)
    end

    def render_nic(nic, context, *args)
      return '' unless nic_renderer
      context.instance_exec(nic, *args, &nic_renderer)
    end

    # Normalize provider-specific NIC data
    # to map to Foreman's expected interfaces_attributes shape.
    def normalize_interfaces(vm_attrs)
      vm_attrs
    end

    def filter_resource_changes(resources)
      return [] if resources.blank?

      result = resources.clone

      result.reject! { |res| recreate_type_allow_list.include?(res['type']) } if recreate_type_allow_list.respond_to? :include?

      result
    end

    # Whether disk renderer emits one collection resource for all disks (for_each)
    # instead of one resource block per disk entry.
    def disk_renderer_collection?
      false
    end
  end
end
