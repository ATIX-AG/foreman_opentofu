require 'test_helper'

class TofuTest < ActiveSupport::TestCase
  # FIXME: be more generic!
  let(:subject) { FactoryBot.create :opentofu_nutanix_cr }

  should validate_presence_of :provider
  should validate_presence_of :url
  should validate_presence_of :user
  should validate_presence_of :password
  should delegate_method(:available_attributes).to(:tofu_provider)
  should delegate_method(:provided_attributes).to(:tofu_provider)
  should delegate_method(:available_images).to(:tofu_provider)
  should delegate_method(:available_ssh_keys).to(:tofu_provider)
  should delegate_method(:capabilities).to(:tofu_provider)

  test 'validates provider is Tofu' do
    subject.provider = 'Unknown'
    assert_not subject.valid?

    subject.provider = 'Tofu'
    assert subject.valid?
  end

  test 'capabilities returns array if undefined' do
    subject.tofu_provider.expects(:capabilities).returns(nil)
    assert_kind_of Array, subject.capabilities
  end

  test 'responds to opentofu_template' do
    assert_respond_to subject, :opentofu_template
  end

  test 'missing provider default template raises' do
    assert_not_include subject.attrs, :opentofu_template_id
    templates = mock
    ProvisioningTemplate.expects(:unscoped).returns(templates)
    templates.expects(:find_by!).with(name: 'Nutanix provision default').raises(ActiveRecord::RecordNotFound)

    assert_raises(ActiveRecord::RecordNotFound) { subject.opentofu_template }
  end

  test 'uses the provider default template when none is assigned' do
    template = mock
    templates = mock
    ProvisioningTemplate.expects(:unscoped).returns(templates)
    templates.expects(:find_by!).with(name: 'Nutanix provision default').returns(template)

    assert_equal template, subject.opentofu_template
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

  test 'validates only connection attributes required by provider' do
    nutanix = FactoryBot.build(:opentofu_nutanix_cr, url: nil, user: nil, password: nil)
    assert_not nutanix.valid?
    assert_includes nutanix.errors[:url], "can't be blank"
    assert_includes nutanix.errors[:user], "can't be blank"
    assert_includes nutanix.errors[:password], "can't be blank"

    hetzner = FactoryBot.build(:opentofu_hetzner_cr, url: nil, user: nil)
    assert hetzner.valid?
  end

  test 'delegates available_attributes to opentofu-provider' do
    assert_equal subject.tofu_provider.available_attributes, subject.available_attributes
  end

  test 'available_resource_ui_select() creates array for selectable_f()' do
    subject.expects(:available_resource).with('config_param1', {}).returns([{ 'name' => 'abc', 'id' => 123, 'foo' => 'bar' }])
    assert_equal [['abc', 123]], subject.available_resource_ui_select('config_param1')
  end

  test 'implements vm_ready(vm), if not delegatable to tofu_provider' do
    vm = mock
    vm.expects(:wait_for)
    assert_not subject.tofu_provider.respond_to?(:vm_ready)
    subject.vm_ready(vm)
  end

  test 'delegates vm_ready(vm)' do
    vm = mock
    subject.tofu_provider.expects(:vm_ready).with(vm)
    assert_respond_to subject.tofu_provider, :vm_ready
    subject.vm_ready(vm)
  end

  test 'skips KeyPair create' do
    client = mock
    client.expects(:key_pairs).never

    ForemanOpentofu::Tofu.any_instance.stubs(:client).returns(client)

    FactoryBot.create :opentofu_nutanix_cr
  end

  test 'creates KeyPair if capability set' do
    client = mock
    key_pairs = mock
    client.expects(:key_pairs).returns(key_pairs)
    key_pairs.expects(:create).returns(OpenStruct.new({
      name: 'something',
      private_key: 'private_key',
      public_key: 'public_key',
    }))
    ForemanOpentofu::Tofu.any_instance.stubs(:client).returns(client)

    FactoryBot.create :opentofu_hetzner_cr

    assert_not_nil KeyPair.find_by(name: 'something')
  end

  test 'can recreate KeyPair' do
    ForemanOpentofu::Tofu.any_instance.stubs(:reset_cached_ssh_keys)
    ForemanOpentofu::ProviderType.any_instance.stubs(:available_ssh_keys).returns([])
    ForemanOpentofu::OpentofuExecuter.any_instance.expects(:run).times(3)
    ForemanOpentofu::TofuKeyPair.any_instance.stubs(:private_key).returns('secret')
    ForemanOpentofu::TofuKeyPair.any_instance.expects(:generate).twice
    cr = FactoryBot.create :opentofu_hetzner_cr
    cr.reload

    cr.recreate
  end

  test 'can reset ssh-key cache' do
    ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
    cr = FactoryBot.create :opentofu_hetzner_cr
    cr.tofu_provider.expects(:reset_cached_ssh_keys)
    cr.reset_cached_ssh_keys
  end

  test 'cache_delete() does nothing' do
    ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
    cr = FactoryBot.create :opentofu_hetzner_cr
    Rails.cache.expects(:delete).never
    cr.cache_delete('')
  end

  test 'cache_delete(something) cleans cache item' do
    ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
    cr = FactoryBot.create :opentofu_hetzner_cr
    Rails.cache.expects(:delete)
    mocked = Minitest::Mock.new
    mocked.expect :delete, nil do |cache_key|
      assert "#{cr.name}_something", cache_key
    end
    Rails.cache.stub(:delete, mocked) do
      cr.cache_delete('something')
    end
  end
end
