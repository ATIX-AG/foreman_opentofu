require 'test_helper'

class TokenTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  def setup
    @token = FactoryBot.create(:foreman_opentofu_token, :token_expired)
  end

  test 'valid token' do
    token = ForemanOpentofu::Token.new(name: 'new-token')
    assert token.valid?
  end

  test 'invalid without name' do
    token = ForemanOpentofu::Token.new
    assert_not token.valid?
  end

  test 'generates new token' do
    old_token = @token.token

    @token.generate_token
    assert_not_equal old_token, @token.token
    assert_not_empty @token.token

    @token.save!
    assert_not_equal old_token, @token.reload.token
  end

  test 'generates valid token' do
    @token.generate_token
    assert_not @token.token_expired?
  end
end
