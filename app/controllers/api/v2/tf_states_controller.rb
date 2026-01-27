module Api
  module V2
    class TfStatesController < ::Api::V2::BaseController
      include ::Api::Version2

      resource_description do
        api_version 'v2'
        api_base_url '/foreman_opentofu/api'
      end

      skip_before_action :verify_authenticity_token
      def show
        state = ForemanOpentofu::TfState.find_by(name: params[:name])
        if state
          render plain: state.state, content_type: 'application/json'
        else
          render plain: '', status: :not_found
        end
      end

      def create
        state = ForemanOpentofu::TfState.find_or_create_by(name: params[:name])

        raw_state = request.body.read
        if raw_state.blank?
          render plain: 'Missing state body', status: :unprocessable_entity
          return
        end
        begin
          JSON.parse(raw_state)

          state.state = raw_state
          state.save!
          render plain: '', status: :ok
        rescue JSON::ParserError => e
          Rails.logger.error("Invalid state JSON: #{e.message}")
          render plain: 'Invalid state format', status: :unprocessable_entity
        end
      end

      def destroy
        state = ForemanOpentofu::TfState.find_by(name: params[:name])
        state&.destroy
        render plain: '', status: :ok
      end

      def resource_class
        @resource_class ||= ForemanOpentofu::TfState
      end
    end
  end
end
