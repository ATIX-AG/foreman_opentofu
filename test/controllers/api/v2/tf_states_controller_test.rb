require 'test_helper'

module Api
  module V2
    class TfStatesControllerTest < ActionController::TestCase
      setup do
        @tf_one = FactoryBot.create(:tf_state)
        @tf_two = FactoryBot.create(:tf_state)
        @token_one = FactoryBot.create(:foreman_opentofu_token, name: @tf_one.name)
        @token_two = FactoryBot.create(:foreman_opentofu_token, name: @tf_two.name)
        @authorization_one = ActionController::HttpAuthentication::Token.encode_credentials(@token_one.token)
        @authorization_two = ActionController::HttpAuthentication::Token.encode_credentials(@token_two.token)
      end

      test 'should show tf_state when present' do
        request.headers['HTTP_AUTHORIZATION'] = @authorization_one
        get :show, params: { name: @tf_one.name }

        assert_response :success
        assert_equal 'application/json; charset=utf-8', @response.content_type

        body = ActiveSupport::JSON.decode(@response.body)
        assert_equal 'bar', body['foo']
      end

      test 'should return 401 when tf_state is missing' do
        request.headers['HTTP_AUTHORIZATION'] = @authorization_one
        get :show, params: { name: 'missing-vm' }

        assert_response :unauthorized
      end

      test 'should return 401 when token expired' do
        @token_one.token_expire = Time.current - 3600
        @token_one.save!

        assert @token_one.token_expired?

        get :show, params: { name: @tf_one.name }

        assert_response :unauthorized
        assert_not_equal @tf_one.state, @response.body
      end

      test 'should create tf_state with valid json body' do
        token = FactoryBot.create(:foreman_opentofu_token, name: 'new-vm')

        attrs = { hello: 'world' }
        request.headers['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token.token)
        @request.env['CONTENT_TYPE'] = 'application/json'
        post :create,
          params: { name: 'new-vm' },
          body: attrs.to_json

        assert_response :success

        tf_state = ForemanOpentofu::TfState.find_by(name: 'new-vm')
        assert_not_nil tf_state
        assert_equal 'world', ActiveSupport::JSON.decode(tf_state.state)['hello']
      end

      test 'should update tf_state when already exists' do
        request.headers['HTTP_AUTHORIZATION'] = @authorization_one
        post :create,
          params: { name: @tf_one.name },
          body: { updated: true }.to_json

        assert_response :success

        assert ActiveSupport::JSON.decode(@tf_one.reload.state)['updated']
      end

      test 'should destroy tf_state when present' do
        assert_difference('ForemanOpentofu::TfState.count', -1) do
          request.headers['HTTP_AUTHORIZATION'] = @authorization_two
          delete :destroy, params: { name: @tf_two.name }
        end

        assert_response :success
      end

      test 'should return ok when destroying missing tf_state' do
        assert_no_difference('ForemanOpentofu::TfState.count') do
          request.headers['HTTP_AUTHORIZATION'] = @authorization_two
          delete :destroy, params: { name: 'missing-vm' }
        end

        assert_response :success
      end
    end
  end
end
