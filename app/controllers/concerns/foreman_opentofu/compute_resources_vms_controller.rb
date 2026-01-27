module ForemanOpentofu
  module ComputeResourcesVmsController
    extend ActiveSupport::Concern
    included do
      prepend Overrides
    end
    module Overrides
      def load_vms
        if @compute_resource.is_a?(ForemanOpentofu::Tofu)
          @vms = []
          return
        end
        super
      end
    end
  end
end
