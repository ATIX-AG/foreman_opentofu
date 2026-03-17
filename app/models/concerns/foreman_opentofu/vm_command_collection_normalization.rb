module ForemanOpentofu
  module VMCommandCollectionNormalization
    private

    def normalize_vm_args_collections!(args)
      [:volumes, :interfaces].each do |collection|
        raw = args.delete(:"#{collection}_attributes") || args[collection]
        next if raw.nil?

        args[collection] = normalize_collection_input(collection, raw)
      end
    end

    def normalize_collection_input(collection, value)
      return nested_attributes_for(collection, value) if value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

      Array(value).map do |entry|
        entry.respond_to?(:deep_symbolize_keys) ? entry.deep_symbolize_keys : entry
      end
    end
  end
end
