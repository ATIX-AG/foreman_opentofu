require 'test_helper'

class TokenTest < ActiveSupport::TestCase
  let(:subject) { FactoryBot.create(:foreman_opentofu_token, :expired) }

  should validate_presence_of :name

  test 'expires' do
    assert subject.expired?

    subject.expire = nil
    assert subject.expired?

    subject.expire = ''
    assert subject.expired?

    subject.expire = Time.zone.now
    assert subject.expired?
  end

  test 'generates new token' do
    old_token = subject.token

    subject.generate
    assert_not_equal old_token, subject.token
    assert_not_empty subject.token

    subject.save!
    assert_not_equal old_token, subject.reload.token
  end

  test 'generates valid token' do
    subject.generate
    assert_not subject.expired?
  end
end
