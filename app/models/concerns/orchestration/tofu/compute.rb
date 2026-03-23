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

      def setUserData
        logger.info "Rendering UserData template for #{name}"
        template = provisioning_template(kind: 'cloud-init')
        template ||= provisioning_template(kind: 'user_data')
        # For some reason this renders as 'built' in spoof view but 'provision' when
        # actually used. For now, use foreman_url('built') in the template
        if template.nil?
          # rubocop:disable Layout/LineLength
          failure(format(_("Image \"%{image}\" needs user data, but \"%{os}\" is not associated to any provisioning template of the kind user_data. Please associate it with a suitable template or uncheck 'User data' from the image definition."),
            image: image.name,
            os: operatingsystem))
          # rubocop:enable Layout/LineLength
          return false
        end

        compute_attributes['user_data'] = render_template(template: template)

        return false if errors.any?
        true
      end
    end
  end
end
