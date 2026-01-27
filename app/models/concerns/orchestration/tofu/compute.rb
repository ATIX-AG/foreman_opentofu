module Orchestration
  module Tofu
    module Compute
      extend ActiveSupport::Concern

      def computeValue(_foreman_attr, fog_attr)
        value = ''
        value += vm.send(fog_attr).to_s
        value
      end

      def match_macs_to_nics(fog_attr)
        interfaces.select(&:physical?).each do |nic|
          mac = vm.send(fog_attr)
          logger.debug "Orchestration::Compute: nic #{nic.inspect} assigned to #{vm.inspect}"
          nic.mac = mac
          nic.reset_dhcp_record_cache if nic.respond_to?(:reset_dhcp_record_cache) # delete the cached dhcp_record with old MAC on managed nics
          return false unless validate_required_foreman_attr(mac, Nic::Base.physical, :mac)
        end
        true
      end
    end
  end
end
