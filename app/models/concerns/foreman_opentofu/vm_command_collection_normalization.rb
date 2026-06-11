module ForemanOpentofu
  module VMCommandCollectionNormalization
    private

    def normalize_vm_args_collections!(args)
      args[:image_id] = args[:image] if args.key?(:image)
      normalize_vm_boolean_args!(args)
      [:volumes, :interfaces].each do |collection|
        raw = args.delete(:"#{collection}_attributes") || args[collection]
        next if raw.nil?

        args[collection] = normalize_collection_input(collection, raw)
      end
    end

    def normalize_vm_boolean_args!(args)
      vm_boolean_keys.each do |key|
        next unless args.key?(key)
        args[key] = Foreman::Cast.to_bool(args[key])
      end
    end

    def vm_boolean_keys
      return [] unless respond_to?(:tofu_provider) && tofu_provider.respond_to?(:attributes)

      tofu_provider.attributes('vm')
                   .select { |attr| attr['type'] == 'bool' }
                   .map { |attr| attr['name'].to_sym }
    end

    def normalize_collection_input(collection, value)
      return normalize_nested_hash_collection(collection, value) if value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

      Array(value).map do |entry|
        entry.respond_to?(:deep_symbolize_keys) ? entry.deep_symbolize_keys : entry
      end
    end

    def normalize_nested_hash_collection(collection, value)
      values = (value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h).deep_stringify_keys
      values.delete("new_#{collection}")

      values.sort_by { |key, _| key.to_s.sub('new_', '').to_i }.filter_map do |_, val|
        normalized = normalize_nested_collection_value(val)
        next if normalized.is_a?(Hash) && normalized[:_delete] == '1' && normalized[:id].blank?

        normalized
      end
    end

    def normalize_nested_collection_value(value)
      normalized =
        if value.is_a?(ActionController::Parameters) && value.respond_to?(:to_unsafe_h)
          value.to_unsafe_h
        elsif value.respond_to?(:to_h)
          value.to_h
        else
          value
        end

      normalized.respond_to?(:deep_symbolize_keys) ? normalized.deep_symbolize_keys : normalized
    end

    def prefill_mandatory_attributes(args)
      # FIXME: add volume/nic attributes
      res = {}
      mandatory_attrs = tofu_provider.attributes('vm').select { |attr| attr['mandatory'] && !args.key?(attr['name']) }
      mandatory_attrs.each do |attribute|
        name = attribute['name'].to_sym
        res[name] = determine_default(attribute) || ''
      end
      res
    end

    def determine_default(attribute)
      return attribute['default'] if attribute.key? 'default'

      options = attribute['options']
      case options
      when Array then options.first
      when Hash
        if options.dig('data_source', 'name')
          dyn_res = fetch_resource(options.dig('data_source', 'name'), options)
          dyn_res&.first&.fetch('id')
        end
      end
    end
  end
end
