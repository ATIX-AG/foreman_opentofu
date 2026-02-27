module ForemanOpentofu
  module NicHelpers
    def nic_attributes(available_attributes)
      interfaces = @cr_attrs['interfaces'] || @cr_attrs['interfaces_attributes']
      return '' if interfaces.blank?

      interfaces = normalize_interfaces(interfaces)
      nic_defs = available_attributes.values.select do |attrs|
        attrs['group'] == 'nic'
      end
      res = ''
      interfaces.each do |iface|
        next if iface['subnet_uuid'].blank?

        res << build_attribute_block('nic_list', iface, nic_defs)
      end
      res
    end

    def normalize_interfaces(interfaces)
      if interfaces.is_a?(Hash)
        if interfaces.keys.all? { |k| k.to_s =~ /^\d+$/ }
          interfaces.values
        else
          [interfaces]
        end
      else
        Array(interfaces)
      end
    end

    def build_attribute_block(block_name, attrs, nic_defs)
      block_data = {}
      attrs.each do |k, v|
        next if v.blank?
        conf = nic_defs.find { |a| (a['name'] || a[:name]) == k }
        next unless conf
        block_data[k] = format_value(v, conf['type']) if conf
      end
      block_to_hcl([block_name], block_data)
    end
  end
end
