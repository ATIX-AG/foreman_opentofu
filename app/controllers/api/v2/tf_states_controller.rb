module Api
  module V2
    class TfStatesController < ::Api::V2::BaseController
      include ::Api::Version2
      include ::Foreman::Controller::FilterParameters

      skip_before_action :set_taxonomy

      # Allow HTTP POST methods without CSRF
      skip_before_action :verify_authenticity_token

      # overwrite authorize with the local token-based authorization
      before_action :authorize, except: [:destroy]

      # Don't log tfstate response in logs as it can have sensitive information
      skip_after_action :log_response_body

      filter_parameters :version, :terraform_version, :serial, :lineage, :outputs, :resources, :tf_state, :check_results

      resource_description do
        api_version 'v2'
        api_base_url '/foreman_opentofu/api'
      end

      def show
        state = ForemanOpentofu::TfState.find_by(name: params[:name])

        return head :not_found unless state

        render plain: state.state, content_type: 'application/json'
      end

      def create
        raw_state = request.raw_post
        if raw_state.blank?
          render plain: 'Missing state body', status: :unprocessable_entity
          return
        end
        begin
          JSON.parse(raw_state)

          state = ForemanOpentofu::TfState.find_or_initialize_by(name: params[:name])
          state.state = raw_state
          state.save!
          head :ok
        rescue JSON::ParserError
          render plain: 'Invalid state format', status: :bad_request
        end
      end

      def destroy
        # TODO: at the moment we want to get 200 OK, if the TfState does not exist.
        #       normally, this would fail with 401, because of no valid token.
        #       Needs re-evaluation, if this is a security risk.
        state = ForemanOpentofu::TfState.where(name: params[:name])
        if state.any?
          authorize
          state.first.destroy
        end

        render plain: '', status: :ok
      end

      def resource_class
        @resource_class ||= ForemanOpentofu::TfState
      end

      private

      def authorize
        authenticate_or_request_with_http_token do |token, _options|
          token = ForemanOpentofu::Token.find_by(name: params[:name], token: token)
          unless token
            Rails.logger.warn('TfState-Auth-Token not found')
            render_error('unauthorized', status: :unauthorized)
            return false
          end

          if token.expired?
            Rails.logger.warn 'TfState token expired, if this keeps happening increase the validity of the token'
            render_error('unauthorized', status: :unauthorized)
            return false
          end

          return true
        end
      end
    end
  end
end
