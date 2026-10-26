module ForemanOpentofu
  class PowerTranslator
    def initialize(input)
      provider_key = case input
                     when ProviderType
                       input.id # e.g., :stackit or :hetzner
                     else
                       input.name if input.respond_to?(:name)
                     end

      # Default fallback if key is nil or missing
      provider_key ||= :default
      @provider_type = ProviderTypeManager.find(provider_key) || ProviderType.new(:default)
    end

    def attribute_name
      mapping[:attribute]
    end

    def action_value(action)
      mapping[:values][action.to_sym]
    end

    def power_state(current_raw_status)
      return :unknown if current_raw_status.blank?
      val = current_raw_status.to_s.downcase
      values = mapping[:values]

      if values[:on].casecmp?(val) then :on
      elsif values[:off].casecmp?(val) then :off
      else
        :unknown
      end
    end

    def power_change_allowed?(resource)
      change = resource.fetch('change', {})
      return true if harmless_power_change?(resource, change)

      return false unless valid_power_update_target?(resource, change)

      compare_plan_changes?(change)
    end

    def harmless_power_change?(resource, change)
      change['actions'] == ['no-op'] || resource['mode'] == 'data'
    end

    def compare_plans_allowed?(before, after, after_unknown, exclude_attr)
      keys = (before.keys + after.keys + after_unknown.keys).uniq
      keys.all? { |key| plan_key_allowed?(key, before, after, after_unknown, exclude_attr) }
    end

    def desired_status(attributes)
      power_state_key = (attributes['power_state'] || attributes[:power_state]).presence || :on
      action = power_state_key.to_s.downcase.to_sym

      mapping[:values][action] || mapping[:values][:on]
    end

    def mapping
      @provider_type.power_mapping
    end

    def disallowed_states
      @provider_type.disallowed_states
    end

    private

    def valid_power_update_target?(resource, change)
      resource['address']&.include?(mapping[:server]) && change.fetch('actions', []) == ['update']
    end

    def compare_plan_changes?(change)
      before = change.fetch('before', {}) || {}
      after = change.fetch('after', {}) || {}
      after_unknown = change.fetch('after_unknown', {}) || {}

      compare_plans_allowed?(before, after, after_unknown, attribute_name.to_s)
    end

    def plan_key_allowed?(key, before, after, after_unknown, exclude_attr)
      return true if key == exclude_attr

      unk_val = after_unknown[key]
      return unknown_value_allowed?(key, exclude_attr) if unk_val == true

      b_val = before[key]
      a_val = after[key]

      if [b_val, a_val, unk_val].any?(Hash)
        compare_plans_allowed?(b_val.to_h, a_val.to_h, unk_val.to_h, nil)
      else
        b_val == a_val
      end
    end

    def unknown_value_allowed?(key, exclude_attr)
      exclude_attr.nil? || @provider_type.computed_metadata_keys.include?(key)
    end
  end
end
