module ForemanOpentofu
  module OpentofuVMCommands
    include ForemanOpentofu::VMCommandCollectionNormalization

    def find_vm_by_uuid(uuid)
      vm_command_errors('find vm') do
        tf_state = ForemanOpentofu::TfState.find_by(uuid: uuid)
        data = client({ 'name' => tf_state&.name }).run_output
        # trying to add a volume with invalid parameter may persist in the volumes_attributes-hash
        data['volumes_attributes'] = data['volumes_attributes']&.delete_if { |_idx, vol| vol.key?('id') && vol['id'].nil? }
        ComputeVM.new(self, data)
      end
    end

    def new_vm(args = {})
      vm_command_errors('new vm') do
        args = default_attributes.merge(args).to_h.symbolize_keys
        normalize_vm_args_collections!(args)
        args = prefill_mandatory_attributes(args).merge(args)
        executor = client(args)
        data = executor.run_new
        attrs = data['resource_changes'].first['change']['after'] || {}
        attrs = args.deep_stringify_keys.merge(attrs.to_h.deep_stringify_keys)
        ComputeVM.new(self, attrs)
      end
    end

    def create_vm(args = {})
      vm_command_errors('create vm') do
        args = default_attributes.merge(args).to_h.symbolize_keys
        normalize_vm_args_collections!(args)
        executor = client(args)
        output = executor.run_create(cleanup_on_failure: true)
        ComputeVM.new(self, output)
      end
    end

    def destroy_vm(uuid)
      tf_state = ForemanOpentofu::TfState.find_by(uuid: uuid)
      client({ 'name' => tf_state&.name }).run_destroy
      return unless tf_state

      Rails.logger.info "Deleting tfstate for #{tf_state&.name}"
      tf_state.destroy
    end

    def start_vm(name)
      output = client({ 'name' => name, 'power_state' => 'on' }).run_create
      output['vm']['power_state'] == 'on'
    end

    def stop_vm(name)
      output = client({ 'name' => name, 'power_state' => 'off' }).run_create
      output['vm']['power_state'] == 'off'
    end

    def save_vm(uuid, attrs)
      old_attrs = vm_compute_attributes_for(uuid).to_h.deep_stringify_keys
      tf_state = TfState.find_by(uuid: uuid)
      raise StandardError, "VM with UUID #{uuid} does not exist" unless tf_state
      vm_command_errors('update vm') do
        new_attrs = attrs.to_h.deep_stringify_keys
        merged_attrs = old_attrs.merge(new_attrs).deep_symbolize_keys
        normalize_vm_args_collections!(merged_attrs)
        data = client({ 'name' => tf_state.name }.merge(merged_attrs)).run_create(raise_if_recreate: true)
        ComputeVM.new(self, data)
      end
    end

    def fetch_resource(resource_name = '', options = {})
      client({ 'resource' => { name: resource_name, options: options } }).run_fetch
    end

    def test_connection(options = {})
      super
      begin
        client.run_test_connection
      rescue StandardError => e
        Rails.logger.error("OpenTofu test connection failed: #{e.message}")
        errors.add(:base, e.message)
      end
    end

    private

    def vm_command_errors(method_name)
      yield
    rescue StandardError => e
      Foreman::Logging.exception("Caught #{provider} error", e)
      raise ::Foreman::WrappedException.new(
        e,
        N_(
          "Foreman could not find a required %<provider>s resource in #{method_name}. " \
          'Check if Foreman has the required permissions and the resource exists. Reason: %<error>s'
        ),
        { provider: provider, error: e.message }
      )
    end

    def client(args = {})
      OpentofuExecuter.new(self, args)
    end
  end
end
