require 'test_plugin_helper'

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

      test 'should return 401 when token does not match requested tf_state name' do
        request.headers['HTTP_AUTHORIZATION'] = @authorization_one
        get :show, params: { name: 'missing-vm' }

        assert_response :unauthorized
      end

      test 'should return 404 when tf_state is missing' do
        token = FactoryBot.create(:foreman_opentofu_token, name: 'missing-vm')
        request.headers['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token.token)

        get :show, params: { name: 'missing-vm' }

        assert_response :not_found
      end

      test 'should return 401 when token expired' do
        @token_one.expire = Time.current - 3600
        @token_one.save!

        assert @token_one.expired?

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

      test 'should return 422 when creating tf_state with empty raw body' do
        raw_request = @request
        raw_request.stubs(:raw_post).returns('')
        @controller.request = raw_request
        @controller.set_response!(@response)
        @controller.stubs(:params).returns(ActionController::Parameters.new(name: 'new-vm'))

        assert_no_difference('ForemanOpentofu::TfState.count') do
          @controller.create
        end

        assert_response :unprocessable_entity
        assert_equal 'Missing state body', @response.body
      end

      test 'should return 400 when creating tf_state with invalid json body' do
        token = FactoryBot.create(:foreman_opentofu_token, name: 'new-vm')
        request.headers['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials(token.token)
        @request.env['CONTENT_TYPE'] = 'application/json'

        assert_no_difference('ForemanOpentofu::TfState.count') do
          post :create,
            params: { name: 'new-vm' },
            body: '{invalid json'
        end

        assert_response :bad_request
        assert_includes @response.body, 'There was a problem in the JSON you submitted'
      end

      test 'should update tf_state when already exists' do
        request.headers['HTTP_AUTHORIZATION'] = @authorization_one
        post :create,
          params: { name: @tf_one.name },
          body: { updated: true }.to_json

        assert_response :success

        assert ActiveSupport::JSON.decode(@tf_one.reload.state)['updated']
      end

      test 'should filter sensitive tfstate params from create request logs' do
        request_params = {
          'name' => @tf_one.name,
          'version' => 4,
          'terraform_version' => '1.9.0',
          'serial' => 12,
          'lineage' => 'lineage-id',
          'outputs' => { 'token' => 'secret-output' },
          'resources' => [{ 'instances' => [{ 'attributes' => { 'password' => 'secret' } }] }],
          'tf_state' => { 'resources' => { 'attributes' => { 'password' => 'secret' } } },
          'check_results' => { 'checks' => ['secret'] },
        }
        filtered_request = OpenStruct.new(filtered_parameters: request_params.deep_dup)

        @controller.stubs(:request).returns(filtered_request)
        Api::V2::BaseController.any_instance.stubs(:process_action).returns(nil)
        Foreman::Controller::FilterParameters.instance_method(:process_action).bind(@controller).call('')

        filtered = filtered_request.filtered_parameters
        assert_equal '[FILTERED]', filtered['version']
        assert_equal '[FILTERED]', filtered['terraform_version']
        assert_equal '[FILTERED]', filtered['serial']
        assert_equal '[FILTERED]', filtered['lineage']
        assert_equal '[FILTERED]', filtered['outputs']
        assert_equal '[FILTERED]', filtered['resources']
        assert_equal '[FILTERED]', filtered['tf_state']
        assert_equal '[FILTERED]', filtered['check_results']
        assert_equal @tf_one.name, filtered['name']
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
