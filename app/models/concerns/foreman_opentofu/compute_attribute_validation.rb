module ForemanOpentofu
  module ComputeAttributeValidation
    extend ActiveSupport::Concern

    included do
      validate :validate_opentofu_vm_attributes
    end

    private

    def validate_opentofu_vm_attributes
      return unless compute_resource.is_a?(ForemanOpentofu::Tofu)

      args = compute_resource.default_attributes.merge(vm_attrs.deep_dup).to_h.symbolize_keys
      compute_resource.normalize_vm_args_collections!(args)
      provider = compute_resource.tofu_provider

      begin
        provider.validate_vm!(args, compute_resource)
      rescue ArgumentError => e
        errors.add(:base, e.message)
      end
    end
  end
end
