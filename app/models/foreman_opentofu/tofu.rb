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
    include KeyPairComputeResource
    validates :provider, presence: true, inclusion: { in: %w[Tofu] }
    validates :url, presence: true, if: -> { mandatory_compute_resource_attribute?('url') }
    validates :user, presence: true, if: -> { mandatory_compute_resource_attribute?('user') }
    validates :password, presence: true, if: -> { mandatory_compute_resource_attribute?('password') }

    # alias_attribute :username, :user
    # alias_attribute :endpoint, :url

    delegate :available_attributes, :render_disk, :render_nic, to: :tofu_provider

    def capabilities
      # do not delegate to avoid problems with (Foreman::)KeyPairCapabilities concern
      # Attention: KeyPairCapabilities concern adds 'key_pair'-capabilities to all OpenTofu compute resources!
      tofu_provider.capabilities || []
    end

    def available_images
      # make sure available_images can use this CR, e.g. for requesting data_source
      tofu_provider.available_images(self)
    end

    def available_ssh_keys
      # make sure available_ssh_keys can use this CR, e.g. for requesting data_source
      tofu_provider.available_ssh_keys(self)
    end

    def reset_cached_ssh_keys
      tofu_provider.reset_cached_ssh_keys(self)
    end

    def provided_attributes
      super.merge(tofu_provider.provided_attributes || {})
    end

    def user_data_supported?
      true
    end

    def opentofu_provider
      attrs[:opentofu_provider]
    end

    def opentofu_provider=(value)
      attrs[:opentofu_provider] = value
    end

    def opentofu_template
      return ProvisioningTemplate.find(attrs[:opentofu_template_id]) if attrs[:opentofu_template_id].present?

      ProvisioningTemplate.unscoped.find_by!(
        name: tofu_provider.default_template
      )
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

    def self.model_name
      ComputeResource.model_name
    end

    def default_attributes
      tofu_provider&.default_attributes || {}
    end

    def supports_update?
      true
    end

    def vm_ready(vm)
      return tofu_provider.vm_ready(vm) if tofu_provider.respond_to? :vm_ready

      vm.wait_for { ready? }
    end

    def tofu_provider
      ProviderTypeManager.find(opentofu_provider)
    end

    def new_interface(attr = {})
      OpenStruct.new(attr)
    end

    def new_volume(attr = {})
      OpenStruct.new(attr.merge({}))
    end

    def default_volumes
      tofu_provider&.default_volumes || {}
    end

    def default_interfaces
      tofu_provider&.default_interfaces || {}
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

    def cache_delete(resource_name)
      cache.delete("#{name}_#{resource_name}") if resource_name.present?
    end

    def available_resource_ui_select(resource_name, options = {})
      available_resource(resource_name, options)&.map { |obj| [obj['name'], obj['id']] }
    end

    def vm_compute_attributes(vm)
      vm_attrs = super
      tofu_provider.normalize_interfaces(vm_attrs)
    end

    private

    def mandatory_compute_resource_attribute?(name)
      tofu_provider&.connection_attrs&.any? do |attribute|
        attribute['name'] == name && attribute['mandatory']
      end
    end

    def set_vm_volumes_attributes(vm, vm_attrs)
      volumes = if vm.respond_to?(:volumes_attributes)
                  vm.volumes_attributes.values
                else
                  []
                end
      vm_attrs[:volumes_attributes] = Hash[
        volumes.each_with_index.map do |volume, idx|
          attrs = volume.respond_to?(:attributes) ? volume.attributes : volume
          [idx.to_s, attrs]
        end
      ]
      vm_attrs
    end

    ### overwrite from KeyPairComputeResource
    def setup_key_pair
      return unless tofu_provider.capabilities.include? :key_pair

      # Need to create KeyPair in the Backend, so the backend has the public-key!
      key = client.key_pairs.create name: "foreman-#{id}#{Foreman.uuid}"
      # ...because Foreman does not save the public-key!
      KeyPair.create! name: key.name, compute_resource_id: id, secret: key.private_key, public: key.public_key
    rescue StandardError => e
      Foreman::Logging.exception('Failed to generate key pair', e)
      destroy_key_pair
      raise
    end
  end
end
