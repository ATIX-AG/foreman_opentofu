require 'test_helper'

module ForemanOpentofu
  class KeyPairsTest < ActiveSupport::TestCase
    let(:subject) do
      tofu_exec = mock
      tofu_exec.stubs(:run_create_key)

      KeyPairs.new tofu_exec
    end

    test 'based on Array' do
      assert_kind_of Array, subject
    end

    test 'create() returns TofuKeyPair' do
      TofuKeyPair.any_instance.stubs(:generate)
      key_pair = subject.create name: 'NewPair'

      assert_kind_of TofuKeyPair, key_pair
      assert_equal 'NewPair', key_pair.name
    end

    test 'get() returns TofuKeyPair' do
      kp = KeyPair.create!(name: 'test', secret: 'very secret', compute_resource: FactoryBot.create(:compute_resource))

      tkp = subject.get('test')
      assert_respond_to tkp, :opentofu_executer
      assert_equal kp, tkp.instance_variable_get('@keypair')
    end
  end
end
