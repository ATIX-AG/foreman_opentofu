module ForemanOpentofu
  class ProviderType
    attr_reader :id, :name, :default_attributes, :default_interfaces, :default_volumes,
      :connection_attrs
    attr_accessor :capabilities, :disk_renderer, :nic_renderer,
      :recreate_type_allow_list, :default_template

    def initialize(id)
      @id = id.to_sym
      @name = id.capitalize
      @capabilities = [:build]
      @provider_attrs = []
      @connection_attrs = []
    end

    def provider_attrs=(input)
      @provider_attrs = normalize_attributes(input)
    end

    def connection_attrs=(input)
      @connection_attrs = normalize_attributes(input)
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

    def validate_vm!(vm_attrs, compute_resource)
      attrs = vm_attrs.with_indifferent_access
      validate_attribute_constraints!(attrs, compute_resource)
      validate_provider_specific!(attrs, compute_resource)
    end

    def validate_provider_specific!(_attrs, _compute_resource)
    end

    def active_volumes(attrs, compute_resource)
      disks = attrs[:volumes].presence || compute_resource&.default_volumes
      active_collection(disks)
    end

    def filter_resource_changes(resources)
      return [] if resources.blank?

      result = resources.clone

      result.reject! { |res| recreate_type_allow_list.include?(res['type']) } if recreate_type_allow_list.respond_to? :include?

      result
    end

    # Whether the NIC renderer emits resources for the complete collection.
    def nic_renderer_collection?
      false
    end

    # Whether disk renderer emits one collection resource for all disks (for_each)
    # instead of one resource block per disk entry.
    def disk_renderer_collection?
      false
    end

    # Some providers need user-selected IDs before they can plan a VM. Their
    # initial Foreman form must be built from local attributes instead.
    def plan_on_new_vm?
      true
    end

    private

    def validate_attribute_constraints!(attrs, compute_resource)
      numeric_constraints.each do |attribute|
        constraint_values(attribute, attrs, compute_resource).each do |values|
          value = values.fetch(attribute['name'], attribute['default'])
          next if (value.nil? || value == '') && !attribute['mandatory']

          validate_numeric_constraint!(attribute, value)
        end
      end
    end

    def numeric_constraints
      attributes.select { |attribute| attribute['type'] == 'number' && (attribute.key?('min') || attribute.key?('max')) }
    end

    def constraint_values(attribute, attrs, compute_resource)
      case attribute['group']
      when 'disk'
        active_volumes(attrs, compute_resource)
      when 'vm', nil
        [default_attributes.to_h.with_indifferent_access.merge(attrs)]
      else
        []
      end
    end

    def active_collection(collection)
      collection = collection.values if collection.is_a?(Hash)
      Array(collection).map(&:with_indifferent_access).reject { |entry| entry[:_delete].to_s == '1' }
    end

    def validate_numeric_constraint!(attribute, value)
      field = [name, attribute['name']].join(' ')
      raise ArgumentError, format(_('%<attribute>s must be present.'), attribute: field) if value.nil? || value == ''

      number = constraint_number!(attribute, value, field)
      raise ArgumentError, format(_('%<attribute>s must be greater than or equal to %<minimum>s.'), attribute: field, minimum: attribute['min']) if attribute['min'] && number < attribute['min']
      raise ArgumentError, format(_('%<attribute>s must be less than or equal to %<maximum>s.'), attribute: field, maximum: attribute['max']) if attribute['max'] && number > attribute['max']
    end

    def constraint_number!(attribute, value, field)
      if attribute['step'] == 1
        raise ArgumentError, format(_('%<attribute>s must be a whole number.'), attribute: field) unless value.to_s.match?(/\A-?[0-9]+\z/)

        return value.to_i
      end

      number = Float(value, exception: false) unless value.is_a?(String) && value != value.strip
      raise ArgumentError, format(_('%<attribute>s must be a number.'), attribute: field) unless number&.finite?

      number
    end

    def normalize_attributes(input)
      Array(input).map do |attr|
        ActiveSupport::HashWithIndifferentAccess.new(attr)
      end
    end
  end
end
