require 'test_helper'

class TfStateTest < ActiveSupport::TestCase
  let(:subject) { FactoryBot.create :tf_state }

  should validate_presence_of :name

  test 'state is encrypted' do
    expected_state = '{"state": {"key1": "value1"}}'

    subject.expects(:encryption_key).at_least_once.returns('25d224dd383e92a7e0c82b8bf7c985e815f34cf5')
    subject.state = expected_state
    as_admin do
      assert subject.save
    end
    assert_equal subject.state, expected_state
    assert_not_equal subject.state_in_db, expected_state
  end
end
