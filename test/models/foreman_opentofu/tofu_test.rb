require 'test_helper'

class TofuTest < ActiveSupport::TestCase
  # FIXME: be more generic!
  let(:subject) { FactoryBot.create :opentofu_nutanix_cr }

  should validate_presence_of :provider
  should validate_presence_of :url
  should validate_presence_of :user
  should validate_presence_of :password
  should delegate_method(:available_attributes).to(:tofu_provider)

  test 'validates provider is Tofu' do
    subject.provider = 'Unknown'
    assert_not subject.valid?

    subject.provider = 'Tofu'
    assert subject.valid?
  end

  test 'responds to opentofu_template' do
    assert_respond_to subject, :opentofu_template
  end

  test 'not assigned template returns nil' do
    assert_not_include subject.attrs, :opentofu_template_id

    assert_nil subject.opentofu_template
  end

  test 'has tofu-template' do
    template = FactoryBot.create(:provisioning_template) # , template_kind: FactoryBot.create(:template_kind, name: 'opentofu_script'))
    subject.opentofu_template_id = template.id

    assert_equal template, subject.opentofu_template
  end

  test 'has tofu provider' do
    assert_instance_of Symbol, subject.opentofu_provider
    assert_instance_of ForemanOpentofu::ProviderType, subject.tofu_provider
  end

  test 'delegates available_attributes to opentofu-provider' do
    assert_equal subject.tofu_provider.available_attributes, subject.available_attributes
  end
end
