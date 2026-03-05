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
  end
end
