require 'test_helper'

module ForemanOpentofu
  class TofuKeypairTest < ActiveSupport::TestCase
    # Added public and secret key to key_pair to avoid Minitest 6 deprecation warning for assert_nil
    let(:key_pair) do
      FactoryBot.create(:key_pair, public: 'ssh-rsa test-public', secret: 'test-private')
    end
    let(:subject) { TofuKeyPair.new key_pair.name }

    test 'finds KeyPair' do
      assert_equal key_pair.public, subject.public_key
      assert_equal key_pair.secret, subject.private_key
      assert_equal key_pair.name, subject.name
    end

    test 'generates key' do
      subject.generate

      assert subject.private_key.starts_with? '-----BEGIN PRIVATE KEY-----'
      assert subject.public_key.starts_with? 'ssh-rsa '
    end

    test 'destroys key' do
      kp_id = key_pair.id
      subject.opentofu_executer = mock
      subject.opentofu_executer.expects(:run_destroy_key)

      subject.destroy

      assert_not KeyPair.exists?(id: kp_id)
    end
  end
end
