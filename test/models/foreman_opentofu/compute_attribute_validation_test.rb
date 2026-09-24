require 'test_plugin_helper'

class ComputeAttributeValidationTest < ActiveSupport::TestCase
  setup do
    User.current = users(:admin)
    ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
    @resource = FactoryBot.create(:opentofu_hetzner_cr)
    @profile = FactoryBot.create(:compute_profile)
    @attributes = ComputeAttribute.new(compute_resource: @resource, compute_profile: @profile)
    @resource.expects(:client).never
  end

  test 'Hetzner profile rejects volumes below 10 GB and accepts the minimum size' do
    @resource.expects(:new_vm).never
    @attributes.vm_attrs = { 'volumes_attributes' => { '0' => { 'size' => '9' } } }

    assert_not @attributes.save
    assert_includes @attributes.errors[:base], 'Hetzner size must be greater than or equal to 10.'

    @attributes.vm_attrs = { 'volumes_attributes' => { '0' => { 'size' => '10' } } }
    assert @attributes.valid?
  end

  test 'Hetzner profile preserves saved volumes when an update is invalid' do
    @resource.stubs(:new_vm).returns(ForemanOpentofu::ComputeVM.new(@resource, {}))
    attrs = { 'volumes_attributes' => { '0' => { 'size' => '20' } } }
    @attributes.vm_attrs = attrs.deep_dup
    assert @attributes.save

    assert_not @attributes.update(vm_attrs: { 'volumes_attributes' => { '0' => { 'size' => '10241' } } })
    assert_includes @attributes.errors[:base], 'Hetzner size must be less than or equal to 10240.'
    assert_equal attrs, @attributes.reload.vm_attrs
  end

  test 'Hetzner profile requires a format for automounted volumes' do
    @resource.expects(:new_vm).never
    disk = { 'size' => '10', 'automount' => '1' }
    @attributes.vm_attrs = { 'volumes_attributes' => { '0' => disk } }

    assert_not @attributes.save
    assert_includes @attributes.errors[:base], 'Hetzner volume format is required when automount is enabled.'

    @attributes.vm_attrs = { 'volumes_attributes' => { '0' => disk.merge('format' => 'ext4') } }
    assert @attributes.valid?
  end

  test 'Nutanix profile rejects zero CPU or memory values' do
    resource = FactoryBot.create(:opentofu_nutanix_cr)
    resource.expects(:client).never
    resource.expects(:new_vm).never
    @attributes.compute_resource = resource

    %w[num_sockets num_vcpus_per_socket memory_size_mib].each do |attribute|
      @attributes.vm_attrs = { attribute => '0' }

      assert_not @attributes.save
      assert_includes @attributes.errors[:base], "Nutanix #{attribute} must be greater than or equal to 1."

      @attributes.vm_attrs = { attribute => '1' }
      assert @attributes.valid?
    end
  end

  test 'Nutanix profile validates nested disk sizes without changing the input' do
    resource = FactoryBot.create(:opentofu_nutanix_cr)
    resource.expects(:client).never
    resource.expects(:new_vm).never
    @attributes.compute_resource = resource
    attrs = { 'volumes_attributes' => { '0' => { 'disk_size_mib' => '0' } } }
    @attributes.vm_attrs = attrs.deep_dup

    assert_not @attributes.save
    assert_includes @attributes.errors[:base], 'Nutanix disk_size_mib must be greater than or equal to 1.'
    assert_equal attrs, @attributes.vm_attrs

    @attributes.vm_attrs = { 'volumes_attributes' => { '0' => { 'disk_size_mib' => '1024' } } }
    assert @attributes.valid?
  end
end
