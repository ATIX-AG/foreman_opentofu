require 'test_plugin_helper'

module ForemanOpentofu
  class ComputeResourcesControllerTest < ActiveSupport::TestCase
    test 'provider_selected builds a Tofu resource for a marked inner provider request' do
      controller = ::ComputeResourcesController.new
      params = ActionController::Parameters.new(
        provider: 'nutanix',
        opentofu_provider_selected: 'true'
      )
      compute_resource = mock
      default_template = mock
      default_template.stubs(:id).returns(42)

      controller.stubs(:params).returns(params)
      ComputeResource.expects(:new_provider).with(provider: 'Tofu').returns(compute_resource)
      compute_resource.expects(:opentofu_provider=).with('nutanix')
      compute_resource.expects(:opentofu_template).returns(default_template)
      compute_resource.expects(:opentofu_template_id=).with(42)
      controller.expects(:render).with(partial: 'form')

      controller.provider_selected
    end

    test 'provider_selected preserves the Foreman behavior for an unmarked request' do
      controller = ::ComputeResourcesController.new
      params = ActionController::Parameters.new(provider: 'Libvirt')
      compute_resource = mock

      controller.stubs(:params).returns(params)
      ComputeResource.expects(:new_provider).with(provider: 'Libvirt').returns(compute_resource)
      controller.expects(:render).with(
        partial: 'compute_resources/form',
        locals: { compute_resource: compute_resource }
      )

      controller.provider_selected
    end
  end
end
