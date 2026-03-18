module ForemanOpentofu
  module NicHelpers
    include ForemanOpentofu::HclFormat

    def nic_attributes(block_name = nil)
      nic_defs = @compute_resource.available_attributes('nic')
      interfaces = normalize_interfaces(@cr_attrs['interfaces'] || @cr_attrs['interfaces_attributes'])
      res = ''
      interfaces.each do |iface|
        missing_attrs = nic_defs.select { |name, cfg| cfg[:mandatory] && iface[name].blank? }
        # TODO: log the fact that we skip this due to missing mandatory attributes
        next unless missing_attrs.empty?

        res << if block_given?
                 yield(iface, nic_defs)
               else
                 block_to_hcl([block_name], sanitize_attributes(iface, nic_defs), depth: 1)
               end
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

    def sanitize_attributes(attrs, defs)
      data = {}
      attrs.each do |k, v|
        next if v.blank?

        next unless defs[k]

        data[k] = format_value(v, defs.dig(k, :type))
      end
      data
    end
  end
end
