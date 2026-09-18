module ForemanOpentofu
  module ComputeResourcesController
    extend ActiveSupport::Concern

    included do
      prepend Overrides
    end

    module Overrides
      def provider_selected
        return super unless params[:opentofu_provider_selected]

        @compute_resource = ComputeResource.new_provider(provider: 'Tofu')
        @compute_resource.opentofu_provider = params[:provider]
        default_template = @compute_resource.opentofu_template
        @compute_resource.opentofu_template_id = default_template.id if default_template

        render partial: 'form'
      end
    end
  end
end
