module ForemanOpentofu
  module Concerns
    module BaseTemplateScopeExtensions
      extend ActiveSupport::Concern
      extend ApipieDSL::Module

      apipie :class, 'Base macros related to Opentofu templates' do
        name 'Base Content'
        sections only: %w[all provisioning]
      end

      apipie :method, 'Returns all VM parameters' do
        required :skip_list, Array, desc: 'List of parameters to skip'
        returns String, desc: '"key = value" lines'
      end

      def vm_attributes(skip_list = [])
        available_attributes = @compute_resource.available_attributes
        res = ''
        @cr_attrs.each do |key, value|
          next if skip_list.include? key

          conf = available_attributes[key]
          if conf.nil?
            Rails.logger.warn("Attribute #{key.inspect} is not supported.")
            next
          end
          next if conf['group'] != 'vm'
          next if value.blank? && !conf['mandatory']

          res << "#{key} = #{format_value(value, conf['type'])}\n"
        end
        res << nic_attributes(available_attributes)
      end

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
        res = "#{block_name} {\n"
        attrs.each do |k, v|
          next if v.blank?
          conf = nic_defs.find { |a| (a['name'] || a[:name]) == k }
          next unless conf
          res << "  #{k} = #{format_value(v, conf['type'])}\n" if conf
        end
        res << "}\n"
        res
      end

      private

      def format_value(val, type)
        case type
        when 'string', 'select' then "\"#{val}\""
        when 'bool' then Foreman::Cast.to_bool(val)
        when 'number' then val.to_i
        else val
        end
      end
    end
  end
end
