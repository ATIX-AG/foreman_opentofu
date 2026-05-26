require 'test_plugin_helper'

module ForemanOpentofu
  class BaseTemplateScopeExtensionsTest < ActiveSupport::TestCase
    test 'backend_block' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= backend_block %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        token: 'secret123',
        host_name: 'host.example.com',
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_not_empty block
      assert_snapshot self, 'backend_block', block
    end

    test 'backend_block without token' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= backend_block %>'
      )
      scope = ::Foreman::Renderer.get_scope
      block = ::Foreman::Renderer.render(source, scope)

      assert_empty block
    end

    test 'terraform_block' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: "<%= terraform_block({ 'myprovider' => { 'source' => 'me/myprovider', 'version' => '1.0.1' } }) %>"
      )
      scope = ::Foreman::Renderer.get_scope
      block = ::Foreman::Renderer.render(source, scope)

      assert_not_empty block
      assert_snapshot self, 'terraform_block', block
    end

    test 'terraform_block with token' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: "<%= terraform_block({ 'myprovider' => { 'source' => 'me/myprovider', 'version' => '1.0.1' } }) %>"
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        token: 'secret123',
        host_name: 'host.example.com',
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_not_empty block
      assert_snapshot self, 'terraform_block_with_token', block
    end

    test 'vm_attributes with no attributes' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= vm_attributes() %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        cr_attrs: {},
        compute_resource: FactoryBot.create(:opentofu_nutanix_cr),
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_empty block
    end

    let(:cr_attrs) do
      {
        'num_sockets' => 2,
        'num_vcpus_per_socket' => 1,
        'memory_size_mib' => 1024,
        'not_allowed_vm_param' => 'This should not be in the Snapshot!',
        'interfaces' => [
          {
            'subnet_uuid' => 'some-uuid',
            'not_allowed_nic_param' => 'This should not be in the Snapshot!',
          },
          {
            'subnet_uuid' => 'another-uuid',
            'not_allowed_nic_param' => 'This should not be in the Snapshot!',
          },
        ],
      }
    end
    test 'vm_attributes with attributes' do
      cr = FactoryBot.create(:opentofu_nutanix_cr)
      cr.expects(:available_attributes).returns({
        'num_sockets' => { 'name' => 'num_sockets', 'type' => 'number', 'group' => 'vm', 'mandatory' => false, 'label' => 'Sockets' },
        'num_vcpus_per_socket' => { 'name' => 'num_vcpus_per_socket', 'type' => 'number', 'group' => 'vm', 'mandatory' => false, 'label' => 'Cores per socket' },
        'memory_size_mib' => { 'name' => 'memory_size_mib', 'type' => 'number', 'group' => 'vm', 'mandatory' => false, 'label' => 'Memory (MB)' },
        'subnet_uuid' => { 'name' => 'subnet_uuid', 'type' => 'select', 'group' => 'nic', 'mandatory' => true, 'label' => 'Subnet' },
      })
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= vm_attributes() %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        cr_attrs: cr_attrs,
        compute_resource: cr,
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_not_empty block
      assert_snapshot self, 'vm_attributes', block
    end

    test 'build_disks renders provider-defined resource snippets' do
      cr = stub(default_volumes: [])
      cr.stubs(:render_disk).with do |disk, render_scope, index|
        disk == { 'size' => 50 } &&
          index.zero? &&
          render_scope.respond_to?(:build_disks)
      end.returns(
        {
          resource: {
            type: 'hcloud_volume',
            name: 'volume1',
            content: { size: 50, server_id: :'hcloud_server.node1.id' },
          },
        }
      )
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= build_disks %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        cr_attrs: { 'volumes' => [
          { 'size' => 50 },
          { '_delete' => '1', 'size' => 60 },  # must be filtered out ;-)
        ] },
        compute_resource: cr,
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_includes block, 'resource "hcloud_volume" "volume1"'
      assert_includes block, 'size = 50'
      assert_includes block, 'server_id = hcloud_server.node1.id'
      assert_not_includes block, 'size = 60'
    end

    test 'hetzner volume rendering forwards delete attribute and filters deleted volumes' do
      ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
      cr = FactoryBot.create(:opentofu_hetzner_cr)
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= build_disks %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        compute_resource: cr,
        cr_attrs: { 'volumes' => [{ '_delete' => '1', 'size' => 60 }] },
      })

      block = ::Foreman::Renderer.render(source, scope)

      assert_equal 1, block.split('resource "hcloud_volume" "volumes"').length - 1
      assert_includes block, 'for_each  = { for k, d in local.disks : tostring(k) => d if try(d["_delete"], "0") != "1" }'
      assert_includes block, '_delete = "1"'
    end

    test 'build_nics renders provider-defined nic blocks' do
      ForemanOpentofu::Tofu.any_instance.stubs(:setup_key_pair)
      cr = FactoryBot.create(:opentofu_hetzner_cr)
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= build_nics %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        cr_attrs: { 'interfaces' => [
          { '_destroy' => '0', 'compute_attributes' => { 'network_id' => '123' } },
          { '_destroy' => '1', 'compute_attributes' => { 'network_id' => '456' } },
        ] },
        compute_resource: cr,
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_equal 1, block.scan("\n  network ").size
      assert_includes block, 'network_id = "123"'
      assert_not_includes block, 'network_id = 123'
      assert_not_includes block, 'network_id = "456"'
    end

    test 'resource_block' do
      source = ::Foreman::Renderer::Source::String.new(
        name: 'Parameter',
        content: '<%= resource_block(@resource) %>'
      )
      scope = ::Foreman::Renderer.get_scope(variables: {
        resource: {
          name: 'resource_name',
          options: {
            output_path_postfix: 'stuff',
            entity: {
              id: 'identifier',
              additional_key: 'key1',
            },
          },
        }.with_indifferent_access,
      })
      block = ::Foreman::Renderer.render(source, scope)

      assert_not_empty block
      assert_snapshot self, 'resource_block', block
    end
  end
end
