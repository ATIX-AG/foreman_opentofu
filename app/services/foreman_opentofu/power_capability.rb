module ForemanOpentofu
  module PowerCapability
    module_function

    def power_change_disabled_for_host?(host)
      cr = host&.compute_resource
      return false unless cr.is_a?(ForemanOpentofu::Tofu)

      cr.tofu_provider&.capabilities&.include?(:power_status_only)
    rescue StandardError
      false
    end
  end
end
