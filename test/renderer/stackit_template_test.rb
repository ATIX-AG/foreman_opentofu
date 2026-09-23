require 'test_plugin_helper'

class StackitTemplateTest < ActiveSupport::TestCase
  test 'uses compute resource variables without embedding credentials' do
    rendered = render_stackit({}, dry_run: true)

    assert_includes rendered, 'source = "stackitcloud/stackit"'
    assert_includes rendered, 'default_region      = "eu01"'
    assert_includes rendered, 'service_account_key = var.password'
    assert_not_includes rendered, 'var.endpoint'
    assert_not_includes rendered, 'test-only'
    assert_not_includes rendered, 'resource "stackit_'
    assert_not_includes rendered, 'output "vm_attrs"'
  end

  test 'retains legacy deployment key rendering for cleanup' do
    key = OpenStruct.new(name: 'foreman-deploy', public_key: 'ssh-rsa test-public-key')
    rendered = render_stackit({}, keygen: true, ssh_key: key)

    assert_includes rendered, 'resource "stackit_key_pair" "deploy_key"'
    assert_includes rendered, 'public_key = "ssh-rsa test-public-key"'
    assert_not_includes rendered, 'resource "stackit_server"'
    assert_not_includes rendered, 'resource "stackit_network_interface"'
  end

  test 'renders a volume-backed server and maps its provider UUID and address' do
    rendered = render_stackit

    assert_includes rendered, 'machine_type = "g2i.1"'
    assert_includes rendered, 'project_id        = var.username'
    assert_includes rendered, 'image_id          = "22222222-2222-4222-8222-222222222222"'
    assert_includes rendered, 'source_id             = local.image_id'
    assert_includes rendered, 'boot_volume_size  = 64'
    assert_includes rendered, 'security_group_ids = try(each.value.security_group_id, "") != "" ? [each.value.security_group_id] : null'
    assert_includes rendered, 'network_interfaces = [for nic in values(stackit_network_interface.interfaces) : nic.network_interface_id]'
    assert_includes rendered, 'identity      = stackit_server.node1.server_id'
    assert_includes rendered, 'vm_ip_address = local.assign_public_ip ? stackit_public_ip.primary[0].ip : values(stackit_network_interface.interfaces)[0].ipv4'
    assert_includes rendered, 'vm = merge(stackit_server.node1, {'
    assert_includes rendered, 'image_id          = local.image_id'
    assert_not_includes rendered, 'keypair_name'
  end

  test 'creates one unsecured network when no existing network is selected' do
    rendered = render_stackit('network_id' => '')

    assert_equal 1, rendered.scan('resource "stackit_network" "interfaces"').size
    assert_equal 1, rendered.scan('resource "stackit_network_interface" "interfaces"').size
    assert_includes rendered, 'network_name      = "stackit.example.com-network"'
    assert_includes rendered, 'ipv4_prefix_length = 24'
    assert_includes rendered, 'ipv4_nameservers = []'
    assert_includes rendered, 'security           = try(each.value.security_group_id, "") != ""'
    assert_includes rendered, 'network_interfaces = [for nic in values(stackit_network_interface.interfaces) : nic.network_interface_id]'
  end

  test 'renders interfaces added through the VM form' do
    rendered = render_stackit({
      'interfaces' => [
        { 'network_id' => 'network-one', 'security_group_id' => 'security-group-one', 'ip' => nil, 'ip6' => '' },
        { 'network_id' => 'network-two', 'security_group_id' => 'security-group-two' },
      ],
    })

    assert_includes rendered, 'network_id = "network-one"'
    assert_includes rendered, 'network_id = "network-two"'
    assert_includes rendered, 'security_group_id = "security-group-one"'
    assert_includes rendered, 'security_group_id = "security-group-two"'
    assert_not_includes rendered, 'ip ='
    assert_not_includes rendered, 'ip6 ='
  end

  test 'NIC collection rendering filters nested and deleted interfaces' do
    rendered = render_stackit({
      'interfaces_attributes' => {
        '0' => { 'compute_attributes' => { 'network_id' => 'kept-network' } },
        '1' => { '_destroy' => '1', 'compute_attributes' => { 'network_id' => 'destroyed-network' } },
        '2' => { '_delete' => '1', 'network_id' => 'deleted-network' },
      },
    })

    assert_equal 1, rendered.scan('resource "stackit_network_interface" "interfaces"').size
    assert_includes rendered, 'network_id = "kept-network"'
    assert_not_includes rendered.split('output "vm_attrs"').first, 'destroyed-network'
    assert_not_includes rendered.split('output "vm_attrs"').first, 'deleted-network'
  end

  test 'renders and attaches additional volumes' do
    rendered = render_stackit({
      'volumes' => [{
        'name' => 'data',
        'size' => '100',
        'volume_availability_zone' => 'eu01-1',
        'performance_class' => 'storage_premium_perf6',
      }],
    })

    assert_includes rendered, 'resource "stackit_volume" "volumes"'
    assert_includes rendered, 'resource "stackit_server_volume_attach" "volumes"'
    assert_includes rendered, 'server_id  = stackit_server.node1.server_id'
    assert_includes rendered, 'volume_id  = each.value.volume_id'
    assert_includes rendered, 'name = "data"'
    assert_includes rendered, 'size = "100"'
  end

  test 'casts form booleans and boot volume sizes' do
    rendered = render_stackit({ 'assign_public_ip' => '0', 'boot_volume_size' => '80' })

    assert_includes rendered, 'assign_public_ip  = false'
    assert_includes rendered, 'boot_volume_size  = 80'
    assert_includes render_stackit({ 'assign_public_ip' => '1' }), 'assign_public_ip  = true'
  end

  test 'uses cloud-init without referencing a legacy deployment key' do
    key = OpenStruct.new(name: 'foreman-deploy', public_key: 'ssh-rsa test-public-key')
    rendered = render_stackit({ 'user_data' => 'must-not-be-inlined' },
      ssh_key: key, user_data_filename: '/tmp/userdata')

    assert_not_includes rendered, 'keypair_name'
    assert_not_includes rendered, 'resource "stackit_key_pair"'
    assert_includes rendered, 'user_data = file("/tmp/userdata")'
    assert_not_includes rendered, 'must-not-be-inlined'
  end

  test 'quotes inline cloud-init and escapes HCL template directives' do
    literal_token = '%'.concat('{literal}')
    user_data = "#cloud-config\nruncmd: ['echo ${HOME}', 'echo #{literal_token}']"
    rendered = render_stackit({ 'user_data' => user_data })

    assert_includes rendered, 'user_data = "#cloud-config\nruncmd:'
    assert_includes rendered, '$${HOME}'
    assert_includes rendered, '%%{literal}'
  end

  test 'uses VM region without passing it as a server attribute' do
    rendered = render_stackit('region' => 'eu02', 'project_id' => 'obsolete-project')

    assert_includes rendered, 'default_region      = "eu02"'
    assert_includes rendered, 'project_id        = var.username'
    assert_not_includes rendered.split('output "vm_attrs"').first, 'obsolete-project'
    server = rendered.split('resource "stackit_server" "node1" {').last.split('output "vm_attrs"').first
    assert_no_match(/^\s*region\s*=/, server)
  end

  test 'defaults region for compute resource operations without VM attributes' do
    assert_includes render_stackit({ 'region' => nil }, dry_run: true), 'default_region      = "eu01"'
  end

  test 'renders power state and MAC addresses for Foreman' do
    assert_includes render_stackit, 'desired_status = "active"'
    rendered = render_stackit('power_state' => 'off')
    assert_includes rendered, 'desired_status = "inactive"'
    assert_includes rendered, 'power_state       = stackit_server.node1.desired_status == "active" ? "on" : "off"'
    assert_includes rendered, 'mac           = values(stackit_network_interface.interfaces)[0].mac'
    assert_includes rendered, 'mac               = nic.mac'
    assert_includes rendered, 'managed_network   = contains(keys(stackit_network.interfaces), k)'
    assert_not_includes rendered, 'provisioning_attributes'
  end

  test 'reusing VM output retains managed networks and sparse volume keys' do
    rendered = render_stackit({
      'interfaces_attributes' => {
        '0' => { 'network_id' => 'generated-network', 'managed_network' => true, 'mac' => '02:00:00:00:00:01' },
      },
      'volumes_attributes' => {
        '2' => { 'name' => 'data', 'size' => 80, 'volume_availability_zone' => 'eu01-1', 'performance_class' => nil },
      },
    })

    assert_not_includes rendered, 'generated-network'
    assert_includes rendered, '2 = {'
    assert_includes rendered, 'name = "data"'
    assert_no_match(/^\s*performance_class =\s*$/, rendered)
    assert_includes rendered, 'managed_network   = contains(keys(stackit_network.interfaces), k)'
  end

  test 'reusing VM output preserves numeric interface order' do
    interfaces = { '10' => { 'network_id' => 'network-ten' }, '2' => { 'network_id' => 'network-two' } }
    rendered = render_stackit('interfaces_attributes' => interfaces)
    assert_operator rendered.index('network_id = "network-two"'), :<, rendered.index('network_id = "network-ten"')
  end

  private

  def render_stackit(attrs = {}, **variables)
    inline_attrs = variables.select { |key, _value| key.is_a?(String) }
    attrs = inline_attrs.merge(attrs)
    variables = variables.reject { |key, _value| key.is_a?(String) }
    source = Foreman::Renderer::Source::String.new(
      name: 'Stackit provision default',
      content: File.read(ForemanOpentofu::Engine.root.join('app/views/templates/provisioning/stackit_provision_default.erb'))
    )
    defaults = {
      compute_resource: FactoryBot.build(:opentofu_stackit_cr),
      host_name: 'stackit.example.com',
      cr_attrs: {
        'machine_type' => 'g2i.1',
        'region' => 'eu01',
        'image_id' => '22222222-2222-4222-8222-222222222222',
        'network_id' => '33333333-3333-4333-8333-333333333333',
        'security_group_id' => '44444444-4444-4444-8444-444444444444',
      }.merge(attrs).with_indifferent_access,
      resource: nil,
      keygen: false,
      dry_run: false,
      ssh_key: nil,
      user_data_filename: nil,
    }
    scope = Foreman::Renderer.get_scope(source: source, variables: defaults.merge(variables))
    Foreman::Renderer::UnsafeModeRenderer.render(source, scope)
  end
end
