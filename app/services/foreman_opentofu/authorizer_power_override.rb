module ForemanOpentofu
  module AuthorizerPowerOverride
    # Foreman calls can?(permission, subject, cache) with positional args.
    # rubocop:disable Style/OptionalBooleanParameter
    def can?(permission, subject = nil, cache = true)
      if permission.to_s == 'power_hosts' &&
         ForemanOpentofu::PowerCapability.power_change_disabled_for_host?(subject)
        return false
      end

      super(permission, subject, cache: cache)
    end
    # rubocop:enable Style/OptionalBooleanParameter
  end
end
