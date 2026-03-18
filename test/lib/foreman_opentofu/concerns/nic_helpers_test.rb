module ForemanOpentofu
  class NicHelpersTest < ActiveSupport::TestCase
    let(:subject_class) do
      Class.new do
        include ForemanOpentofu::NicHelpers
        attr_accessor :cr_attrs, :compute_resource
      end
    end
    let(:subject) do
      obj = subject_class.new
      obj.compute_resource = FactoryBot.create(:opentofu_nutanix_cr)
      obj.cr_attrs = {
        'interfaces' => [
          { 'subnet_uuid' => 'abc1', 'model' => 'VIRTIO' },
          { 'subnet_uuid' => 'abc2', 'model' => 'VIRTIO' },
        ],
      }
      obj
    end

    test 'nic_attributes()' do
      assert_snapshot self, 'nic_attributes', subject.nic_attributes('nic')
    end

    test 'nic_attributes() with block' do
      snip = subject.nic_attributes do |nic, _defs|
        "network = {\nuuid = #{nic['subnet_uuid']}\n}\n"
      end

      assert_snapshot self, 'nic_attributes_block', snip
    end

    test 'sanitize_attributes()' do
    end
  end
end
