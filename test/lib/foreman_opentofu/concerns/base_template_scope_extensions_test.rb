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
      cr = FactoryBot.create(:opentofu_nutanix_cr)
      cr.stubs(:default_volumes).returns([])
      cr.stubs(:render_disk).with({ 'size' => 50 }, anything, 0).returns(
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

    test 'build_nics renders provider-defined resource snippets' do
      cr = FactoryBot.create(:opentofu_nutanix_cr)
      cr.stubs(:default_nics).returns([])
      cr.stubs(:render_nic).with({ 'network_id' => '123' }, anything, 0).returns(
        {
          resource: {
            type: 'provider_nic',
            name: 'network1',
            content: { network_id: 123 },
          },
        }
      )
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

      assert_includes block, 'resource "provider_nic" "network1"'
      assert_includes block, 'network_id = 123'
      assert_not_includes block, 'network_id = 456'
    end
  end
end
