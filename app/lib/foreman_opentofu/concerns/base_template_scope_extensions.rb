module ForemanOpentofu
  module Concerns
    module BaseTemplateScopeExtensions
      extend ActiveSupport::Concern
      extend ApipieDSL::Module
      include ForemanOpentofu::HclFormat
      include ForemanOpentofu::NicHelpers

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

      apipie :method, 'Add "resource" data_source block' do
        returns String, desc: ''
      end
      def resource_block(resource)
        block = ''
        path = ['data', resource[:name], 'all']

        # data "<%= @resource[:name] %>" "all" {
        # <% @resource.dig(:options, 'data_source', 'arguments')&.each do |key, value| %>
        #   <%= key %> = <%= value.inspect %>
        # <% end %>
        # }
        block << block_to_hcl(path, resource.dig(:options, 'data_source', 'arguments') || {})

        # output "resources" {
        #   value = [ for e in data.<%= @resource[:name] %>.all.<%= @resource.dig(:options, 'output_path_postfix') %>: {
        #     id = e.<%= @resource.dig(:options, 'entity', 'id') || 'id' %>
        #     name = e.<%= @resource.dig(:options, 'entity', 'name') || 'name' %>
        #     # obj = e
        #     } ]
        # }
        block << block_to_hcl(%w[output resources])
        block << '{' << "\n"
        block << "  value = [ for e in data.#{resource[:name]}.all.#{resource.dig(:options, 'output_path_postfix')}: {\n"
        block << "    id = e.#{resource.dig(:options, 'entity', 'id') || 'id'}\n"
        block << "    name = e.#{resource.dig(:options, 'entity', 'name') || 'name'}\n"
        # block << 'obj = e'
        block << '  } ]' << "\n"
        block << '}' << "\n"
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
