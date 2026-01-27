require 'test_plugin_helper'
# require 'models/compute_resources/compute_resource_test_helpers'

module ForemanOpentofu
  class NutanixTest < ActiveSupport::TestCase
    # include ComputeResourceTestHelpers

    let(:subject) { FactoryBot.build_stubbed(:opentofu_nutanix_cr) }

    should validate_presence_of(:url)
    should validate_presence_of(:user)
    should validate_presence_of(:password)
    # should validate_presence_of(:datacenter)
    # should allow_values('vcenter.example.com', 'vcenter').for(:server)

    test 'valid nutanix resource' do
      assert subject.valid?
    end

    # FIXME: some of the following might be redundant
    test 'invalid without URL' do
      subject.url = nil
      assert_not subject.valid?
      assert_includes subject.errors[:url], "can't be blank"
    end

    test 'invalid without username' do
      subject.user = nil
      assert_not subject.valid?
      assert_includes subject.errors[:user], "can't be blank"
    end

    test 'invalid without password' do
      subject.password = nil
      assert_not subject.valid?
      assert_includes subject.errors[:password], "can't be blank"
    end

    test 'provided attributes includes mac' do
      assert_includes subject.provided_attributes.keys, :mac
    end
  end
end
