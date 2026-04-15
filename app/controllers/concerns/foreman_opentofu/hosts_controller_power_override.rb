module ForemanOpentofu
  module HostsControllerPowerOverride
    def power
      if ForemanOpentofu::PowerCapability.power_change_disabled_for_host?(@host)
        return process_error(
          redirect: :back,
          error_msg: _('Power change operations are not enabled on this host.')
        )
      end

      super
    end
  end
end
