require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type_manager"
require "#{ForemanOpentofu::Engine.root}/app/services/foreman_opentofu/provider_type"

ForemanOpentofu::ProviderTypeManager.register('stackit') do
  @capabilities = [:image, :key_pair]
  @default_attributes = { 'power_state' => 'on', 'region' => 'eu01', 'boot_volume_size' => 64, 'assign_public_ip' => false }
  self.default_template = 'Stackit provision default'

  self.connection_attrs = [
    { name: 'user', type: 'string', mandatory: true, label: 'Project ID' },
    { name: 'password', type: 'password', mandatory: true, label: 'Service account key' },
  ]

  def plan_on_new_vm?
    false
  end

  def provided_attributes
    { ip: :vm_ip_address, mac: :mac }
  end

  def vm_ready(vm)
    vm.ready?
  end

  def power_state_attributes(state)
    { 'power_state' => state }
  end

  def desired_status(attributes)
    { 'on' => 'active', 'off' => 'inactive' }.fetch(attributes['power_state'].presence || 'on')
  end

  # Only a power update is allowed during a start/stop action.
  def power_change_allowed?(resource)
    change = resource.fetch('change', {})
    return true if harmless_power_change?(resource, change)

    server_update?(resource, change) && comparable_plan(change, 'before') == comparable_plan(change, 'after')
  end

  def select_nic_for_mac(nics, nic)
    identifier = nic.identifier.to_s
    network_id = nic.compute_attributes.to_h.with_indifferent_access[:network_id]
    find_nic_by_identifier(nics, identifier) || find_nic_by_network(nics, network_id) || default_nic(nics, network_id)
  end

  def disk_renderer_collection?
    true
  end

  def nic_renderer_collection?
    true
  end

  # Stackit exposes individual images by UUID rather than an image-list data
  # source. An empty collection makes Foreman's image form render a manual UUID
  # field instead of a select box.
  def available_images(_compute_resource)
    []
  end

  # Prepare all NICs together so an empty form produces one default network.
  def interfaces_for_template(cr_attrs, context)
    interfaces = context.normalize_interfaces(normalized_interfaces(cr_attrs)).filter_map do |interface|
      normalize_interface(interface, context)
    end
    configured = interfaces.select { |interface| interface['network_id'].present? }
    configured.presence || [fallback_interface(interfaces)]
  end

  def harmless_power_change?(resource, change)
    change['actions'] == ['no-op'] || resource['mode'] == 'data'
  end

  def server_update?(resource, change)
    resource['address'] == 'stackit_server.node1' && change['actions'] == ['update']
  end

  def comparable_plan(change, direction)
    values = change.fetch(direction, {}).dup
    unknown = change.fetch('after_unknown', {})
    ignored = ['desired_status'] + %w[agent created_at launched_at updated_at].select { |key| unknown[key] == true }
    values.except!(*ignored)
    comparable_agent(values, unknown)
  end

  def comparable_agent(values, unknown)
    return values unless unknown['agent']

    agent = values['agent'].to_h
    fields = unknown['agent'].is_a?(Hash) ? unknown['agent'].select { |_key, value| value }.keys : agent.keys
    values['agent'] = agent.except(*fields)
    values
  end

  def find_nic_by_identifier(nics, identifier)
    nics.find { |entry| identifier.present? && entry['identifier'] == identifier }
  end

  def find_nic_by_network(nics, network_id)
    nics.find { |entry| network_id.present? && entry['network_id'] == network_id }
  end

  def default_nic(nics, network_id)
    nics.first if network_id.blank? && nics.all? { |entry| entry['identifier'].blank? }
  end

  def normalized_interfaces(cr_attrs)
    raw = configured_interfaces(cr_attrs)
    return raw unless indexed_interfaces?(raw)

    raw.sort_by { |key, _value| key.to_i }.map(&:last)
  end

  def configured_interfaces(cr_attrs)
    cr_attrs['interfaces'].presence || cr_attrs['interfaces_attributes'].presence ||
      [{ 'network_id' => cr_attrs['network_id'].to_s, 'security_group_id' => cr_attrs['security_group_id'].to_s }]
  end

  def indexed_interfaces?(interfaces)
    interfaces.is_a?(Hash) && interfaces.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
  end

  def normalize_interface(interface, context)
    interface = interface.with_indifferent_access
    return if deleted_interface?(interface)

    attributes = (interface['compute_attributes'].presence || interface).with_indifferent_access
    sanitize_interface(attributes, interface, context)
  end

  def deleted_interface?(interface)
    interface['_delete'].to_i == 1 || interface['_destroy'].to_i == 1
  end

  def sanitize_interface(attributes, interface, context)
    sanitized = context.sanitize_attributes(attributes, available_attributes('nic'))
    sanitized.merge!(attributes.slice('network_id', 'security_group_id').compact_blank)
    sanitized.delete('network_id') if Foreman::Cast.to_bool(attributes['managed_network'])
    sanitized['identifier'] = interface['identifier'] if interface['identifier'].present?
    sanitized
  end

  def fallback_interface(interfaces)
    security_group_id = interfaces.filter_map { |interface| interface['security_group_id'].presence }.first
    { 'security_group_id' => security_group_id, 'identifier' => interfaces.first&.fetch('identifier', nil) }.compact
  end

  self.provider_attrs = [
    { name: 'machine_type', type: 'string', group: 'vm', mandatory: true,
      label: 'Machine type', help: 'Stackit machine type available in your project, for example g2i.1.' },
    { name: 'region', type: 'string', group: 'vm', mandatory: true, default: 'eu01',
      label: 'Region', help: 'Stackit region identifier, for example eu01.' },
    { name: 'availability_zone', type: 'string', group: 'vm', mandatory: false,
      label: 'Availability zone', help: 'Optional Stackit availability zone, for example eu01-1.' },
    { name: 'boot_volume_size', type: 'number', group: 'vm', mandatory: true, default: 64,
      label: 'Boot volume size (GB)', min: 4, max: 16_000, step: 1,
      help: 'Must be between 4 and 16000 GB and at least the minimum disk size of the selected image.' },
    { name: 'network_id', type: 'string', group: 'nic', mandatory: false,
      label: 'Network ID', help: 'Optional UUID of an existing Stackit network. Leave blank to create one.' },
    { name: 'security_group_id', type: 'string', group: 'nic', mandatory: false,
      label: 'Security group ID', help: 'Optional UUID of an existing security group.' },
    { name: 'assign_public_ip', type: 'bool', group: 'vm',
      label: 'Assign public IPv4', help: 'Allocate a public IPv4 address for the first network interface.' },
    { name: 'name', type: 'string', group: 'disk', mandatory: true,
      label: 'Volume name' },
    { name: 'size', type: 'number', group: 'disk', mandatory: true,
      label: 'Size (GB)', min: 1, max: 16_000, step: 1,
      help: 'Volume size must be between 1 and 16000 GB.' },
    { name: 'volume_availability_zone', type: 'string', group: 'disk', mandatory: true,
      label: 'Availability zone' },
    { name: 'performance_class', type: 'string', group: 'disk', mandatory: false,
      label: 'Performance class' },
  ]

  self.nic_renderer = proc do |_nic, _index = 0|
    interfaces = @compute_resource.tofu_provider.interfaces_for_template(@cr_attrs, self)

    <<~HCL
      locals {
        network_name      = #{to_hcl("#{@host_name}-network")}
        interfaces        = #{to_hcl(interfaces, snippet: false)}
        active_interfaces = { for k, nic in local.interfaces : tostring(k) => nic }
      }

      resource "stackit_network" "interfaces" {
        for_each = {
          for k, nic in local.active_interfaces : k => nic
          if try(nic.network_id, "") == ""
        }
        project_id       = local.project_id
        name             = format("%s-%s", local.network_name, each.key)
        routed           = true
        ipv4_prefix_length = 24
        ipv4_nameservers = []
      }

      resource "stackit_network_interface" "interfaces" {
        for_each           = local.active_interfaces
        project_id         = local.project_id
        network_id         = try(each.value.network_id, "") != "" ? each.value.network_id : stackit_network.interfaces[each.key].network_id
        security           = try(each.value.security_group_id, "") != ""
        security_group_ids = try(each.value.security_group_id, "") != "" ? [each.value.security_group_id] : null
      }
    HCL
  end

  self.disk_renderer = proc do |_disk, index = 0|
    next nil unless index.zero?

    attrs = @cr_attrs.respond_to?(:with_indifferent_access) ? @cr_attrs.with_indifferent_access : {}
    defaults = @compute_resource&.default_volumes
    disks = attrs[:volumes].presence || attrs[:volumes_attributes].presence || defaults || {}
    # Optional provider attributes may be null in the returned VM output.
    disks = if disks.is_a?(Hash)
              disks.transform_values(&:compact)
            else
              Array(disks).map(&:compact)
            end
    disks_hcl = respond_to?(:to_hcl) ? to_hcl(disks, snippet: false) : '{}'

    <<~HCL
      locals {
        disks = #{disks_hcl}
      }

      resource "stackit_volume" "volumes" {
        for_each          = { for k, d in local.disks : tostring(k) => d if try(d["_delete"], "0") != "1" }
        project_id        = local.project_id
        name              = each.value.name
        size              = tonumber(each.value.size)
        availability_zone = each.value.volume_availability_zone
        performance_class = try(each.value.performance_class, "") != "" ? each.value.performance_class : null
      }

      resource "stackit_server_volume_attach" "volumes" {
        for_each   = stackit_volume.volumes
        project_id = local.project_id
        server_id  = stackit_server.node1.server_id
        volume_id  = each.value.volume_id
      }
    HCL
  end
end
