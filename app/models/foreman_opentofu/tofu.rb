# frozen_string_literal: true

# This file is part of ForemanOpentofu.

# ForemanOpentofu is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ForemanOpentofu is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with ForemanOpentofu. If not, see <http://www.gnu.org/licenses/>.

module ForemanOpentofu
  class Tofu < ComputeResource
    include OpentofuVMCommands
    include ComputeResourceCaching
    validates :provider, presence: true, inclusion: { in: %w[Tofu] }
    validates :url, presence: true
    validates :user, presence: true
    validates :password, presence: true

    # alias_attribute :username, :user
    # alias_attribute :endpoint, :url

    delegate :available_attributes, to: :tofu_provider

    def provided_attributes
      super.merge(
        mac: :mac
      )
    end

    def opentofu_provider
      attrs[:opentofu_provider]
    end

    def opentofu_provider=(value)
      attrs[:opentofu_provider] = value
    end

    def opentofu_template
      return ProvisioningTemplate.find(attrs[:opentofu_template_id]) if attrs.key? :opentofu_template_id
      # or default-template for this opentofu_provider
      nil
    end

    def opentofu_template_id
      attrs[:opentofu_template_id]
    end

    def opentofu_template_id=(value)
      attrs[:opentofu_template_id] = value
    end

    def self.provider_friendly_name
      'OpenTofu'
    end

    def capabilities
      [:build]
    end

    def self.model_name
      ComputeResource.model_name
    end

    def default_attributes
      tofu_provider&.default_attributes || {}
    end

    def supports_update?
      true
    end

    def tofu_provider
      ProviderTypeManager.find(opentofu_provider)
    end

    def new_interface
      { compute_attributes: {} }
    end

    def new_volume
      { compute_attributes: {} }
    end

    def editable_network_interfaces?
      true
    end

    def available_resource(resource_name, options = {})
      cache.cache("#{name}_#{resource_name}") do
        resource = fetch_resource(resource_name, options)
        resource.map { |h| OpenStruct.new(h) }
      end
    end

    def available_resource_ui_select(resource_name, options = {})
      available_resource(resource_name, options)&.map { |obj| [obj['name'], obj['id']] }
    end
  end
end
