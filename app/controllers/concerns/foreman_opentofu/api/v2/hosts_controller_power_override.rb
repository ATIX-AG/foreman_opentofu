module ForemanOpentofu
  module Api
    module V2
      module HostsControllerPowerOverride
        def power
          if ForemanOpentofu::PowerCapability.power_change_disabled_for_host?(@host)
            return render_error :custom_error, status: :unprocessable_entity, locals: { message: _('Power change operations are not enabled on this host.') }
          end

          super
        end

        def power_status
          result = PowerManager::PowerStatus.safe_power_state(@host, timeout: params[:timeout])
          result[:statusText] = _('Power change operations are not enabled on this host.') if ForemanOpentofu::PowerCapability.power_change_disabled_for_host?(@host)

          render json: result
        end
      end
    end
  end
end
