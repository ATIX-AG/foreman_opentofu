module ForemanOpentofu
  class OpentofuExecuter
    # 'destroy' works with TfState rather than the actual tf-file
    # also it might not receive all the necessary data to create a valid tf-file
    DRY_RUN_MODES = %w[destroy test].freeze

    def initialize(compute_resource, args = {})
      @compute_resource = compute_resource
      @cr_attrs = args.to_h.with_indifferent_access
      @resource = @cr_attrs['resource']
      @host_name = @cr_attrs['name'] || 'test'
      @key_pair = @compute_resource.key_pair
    end

    def run(mode = '')
      Dir.mktmpdir('opentofu_', ForemanOpentofu::OPENTOFU_TMP_PATH) do |dir|
        # FIXME: integrate the user_data-file into AppWrapper!
        if @cr_attrs['user_data']
          @user_data_filename = File.join(dir, 'userdata')
          File.open(@user_data_filename, 'w') do |f|
            f.write(@cr_attrs['user_data'])
          end
        end
        tofu = AppWrapper.new(dir, variables: {
          username: @compute_resource.user,
          password: @compute_resource.password,
          endpoint: @compute_resource.url,
        })
        @use_backend = %w[create destroy output keygen].include?(mode)
        @token = create_token(@host_name) if @use_backend
        tofu.main_configuration = render_template(mode)
        tofu.init
        yield(tofu)
      end
    end

    def run_key(key_pair, &block)
      @host_name = key_pair.name
      @key_pair = key_pair
      run('keygen', &block)
      @compute_resource.reset_cached_ssh_keys
    end

    # creates a new authentication token for the TfState API-controller
    # needed for tofu command to send it's state-file to the database.
    # returns the created token
    def create_token(host_name)
      new_token = nil
      # This construct makes sure the token is created outside of the current transaction
      # which is necessary for the API-controller to check the token, while the current transaction still runs
      # see https://stackoverflow.com/a/11675647
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          token = ForemanOpentofu::Token.find_or_create_by(name: host_name)
          new_token = if token.expired?
                        token.generate
                      else
                        token.token
                      end
        end
      end.join
      new_token
    end

    def run_new
      run('new') do |tofu|
        tofu.plan
        return tofu.show_plan
      end
    end

    def run_test_connection
      run('test', &:plan)
    end

    def run_create(raise_if_recreate: false)
      run('create') do |tofu|
        if raise_if_recreate
          # check the plan in advance to verify we do not replace the VM
          tofu.plan
          raise 'OpenTofu planned to re-create a resource; action aborted (check logs for details)!' if plan_wants_recreate? tofu.show_plan
        end
        tofu.apply
        attrs = tofu.output('vm_attrs')
        ForemanOpentofu::TfState.find_by(name: @cr_attrs['name'])&.update(uuid: attrs['identity'])
        attrs
      end
    end

    def key_pairs
      KeyPairs.new self, @compute_resource.available_ssh_keys
    end

    def run_create_key(key_pair)
      run_key(key_pair, &:apply)
    end

    def run_destroy_key(key_pair)
      run_key(key_pair, &:destroy)
    end

    def run_output
      run('output') do |tofu|
        tofu.output('vm_attrs')
      end
    end

    def run_destroy
      run('destroy', &:destroy)
    end

    def run_fetch
      run do |tofu|
        tofu.apply
        return tofu.output('resources')
      end
    end

    private

    def render_template(mode)
      template = provision_template
      variables = {
        compute_resource: @compute_resource,
        cr_attrs: @cr_attrs,
        use_backend: @use_backend,
        token: @token,
        host_name: @host_name,
        resource: @resource,
        dry_run: dry_run(mode),
        keygen: (mode == 'keygen'),
        ssh_key: @key_pair,
        user_data_filename: @user_data_filename,
      }
      scope = Foreman::Renderer.get_scope(source: template, variables: variables)
      source = Foreman::Renderer.get_source(template: template)
      rendered_template = Foreman::Renderer::UnsafeModeRenderer.render(source, scope)
      raise ::Foreman::Exception, N_('Unable to render provisioning template') unless rendered_template

      rendered_template
    end

    def dry_run(mode)
      mode.empty? || DRY_RUN_MODES.include?(mode)
    end

    def provision_template
      name = @compute_resource.opentofu_template.name
      template = ProvisioningTemplate.unscoped.find_by(name: name)
      unless template
        raise ::Foreman::Exception.new(N_('Unable to find template specified by %s setting'),
          name)
      end

      template
    end

    def plan_wants_recreate?(plan)
      need_recreate = plan['resource_changes'].select { |res| (res.dig('change', 'actions') || []).include?('delete') }
      need_recreate = @compute_resource.tofu_provider.filter_resource_changes need_recreate
      # {
      #   "address": "hcloud_server.node1",
      #   "mode": "managed",
      #   "type": "hcloud_server",
      #   "name": "node1",
      #   "provider_name": "registry.opentofu.org/hetznercloud/hcloud",
      #   "change": {
      #     "actions": [
      #       "create"
      #     ],

      unless need_recreate.empty?
        need_recreate.each do |res|
          Rails.logger.warn("Re-Create of #{res['address']} planned; if this is not an issue add type #{res['type'].inspect} to the allow-list of the ProviderType.")
        end
        return true
      end
      false
    end
  end
end
