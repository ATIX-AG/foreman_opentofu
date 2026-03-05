module ForemanOpentofu
  module Concerns
    module BaseTemplateScopeExtensions
      extend ActiveSupport::Concern
      extend ApipieDSL::Module
      include ForemanOpentofu::HclFormat

      apipie :class, 'Base macros related to Opentofu templates' do
        name 'OpenTofu helpers'
        sections only: %w[opentofu_script]
      end

      apipie :method, 'Returns `terraform`-block including necessary backend definition, if applicable' do
        required :data, Hash, desc: 'Define the provider-type to pull in, e.g. `{ \'nutanix\' => { \'source\' => \'nutanix/nutanix\', \'version\' => \'2.4.0\' }`'
        returns String, desc: '`terraform {}`-block based on the data-input, if applicable with TfState-Backend definition.'
      end
      # e.g. terraform_block({ 'nutanix' => { 'source' => 'nutanix/nutanix', 'version' => '2.4.0' })
      def terraform_block(data)
        block = block_to_hcl(['terraform'])
        block << '{'
        block << block_to_hcl(['required_providers'], data, depth: 1)
        block << backend_block
        block << "\n}"
      end

      apipie :method, 'Returns all VM parameters' do
        required :skip_list, Array, desc: 'List of parameters to skip'
        returns String, desc: '"key = value" lines'
      end
      def vm_attributes(skip_list = [])
        available_attributes = @compute_resource.available_attributes
        data = {}
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

          data[key] = format_value(value, conf['type'])
        end
        res << to_hcl(data, snippet: true)
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
        block_data = {}
        attrs.each do |k, v|
          next if v.blank?
          conf = nic_defs.find { |a| (a['name'] || a[:name]) == k }
          next unless conf
          block_data[k] = format_value(v, conf['type']) if conf
        end
        block_to_hcl([block_name], block_data)
      end

      def format_value(val, type)
        case type
        when 'string', 'select' then val
        when 'bool' then Foreman::Cast.to_bool(val)
        when 'number' then val.to_i
        else val
        end
      end

      def backend_block
        if @token
          data = {
            address: "#{Setting[:foreman_url]}/api/v2/tf_states/#{@host_name}",
            headers: {
              'Authorization' => "Token #{@token}",
            },
          }
          block_to_hcl(%w[backend http], data, depth: 1)
        else
          ''
        end
      end
    end
  end
end
