require 'test_helper'

module Api
  module V2
    class TfStatesControllerTest < ActionController::TestCase
      setup do
        @tf_one = FactoryBot.create(:tf_state)
        @tf_two = FactoryBot.create(:tf_state)
      end

      test 'should show tf_state when present' do
        get :show, params: { name: @tf_one.name }

        assert_response :success
        assert_equal 'application/json; charset=utf-8', @response.content_type

        body = ActiveSupport::JSON.decode(@response.body)
        assert_equal 'bar', body['foo']
      end

      test 'should return 404 when tf_state is missing' do
        get :show, params: { name: 'missing-vm' }

        assert_response :not_found
        assert_equal '', @response.body
      end

      test 'should create tf_state with valid json body' do
        attrs = { hello: 'world' }
        assert_difference('ForemanOpentofu::TfState.count', 1) do
          @request.env['CONTENT_TYPE'] = 'application/json'
          post :create, params: { name: 'new-vm' }, body: attrs.to_json
        end

        assert_response :success

        tf_state = ForemanOpentofu::TfState.find_by(name: 'new-vm')
        assert_not_nil tf_state
        assert_equal 'world', ActiveSupport::JSON.decode(tf_state.state)['hello']
      end

      test 'should update tf_state when already exists' do
        post :create, params: { name: @tf_one.name }, body: { updated: true }.to_json

        assert_response :success

        assert ActiveSupport::JSON.decode(@tf_one.reload.state)['updated']
      end

      test 'should destroy tf_state when present' do
        assert_difference('ForemanOpentofu::TfState.count', -1) do
          delete :destroy, params: { name: @tf_two.name }
        end

        assert_response :success
      end

      test 'should return ok when destroying missing tf_state' do
        assert_no_difference('ForemanOpentofu::TfState.count') do
          delete :destroy, params: { name: 'missing-vm' }
        end

        assert_response :success
      end
    end
  end
end
