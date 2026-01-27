module ForemanOpentofu
  module OpentofuVMCommands
    def find_vm_by_uuid(uuid)
      vm_command_errors('find vm') do
        tf_state = ForemanOpentofu::TfState.find_by(uuid: uuid)
        data = client({ 'name' => tf_state&.name }).run('output')
        ComputeVM.new(self, data)
      end
    end

    def new_vm(args = {})
      vm_command_errors('new vm') do
        args = default_attributes.merge(args)
        executor = client(args)
        data = executor.run('new')
        OpenStruct.new(data['resource_changes'].first['change']['after'])
      end
    end

    def create_vm(args = {})
      vm_command_errors('create vm') do
        args = default_attributes.merge(args)
        executor = client(args)
        output = executor.run('create')
        ComputeVM.new(self, output)
      end
    end

    def destroy_vm(uuid)
      tf_state = ForemanOpentofu::TfState.find_by(uuid: uuid)
      client({ 'name' => tf_state&.name }).run('destroy')
      return unless tf_state

      Rails.logger.info "Deleting tfstate for #{tf_state&.name}"
      tf_state.destroy
    end

    def start_vm(name)
      output = client({ 'name' => name, 'power_state' => 'on' }).run('create')
      output['vm']['power_state'] == 'on'
    end

    def stop_vm(name)
      output = client({ 'name' => name, 'power_state' => 'off' }).run('create')
      output['vm']['power_state'] == 'off'
    end

    def save_vm(uuid, attrs)
      tf_state = TfState.find_by(uuid: uuid)
      raise StandardError, "VM with UUID #{uuid} does not exist" unless tf_state
      vm_command_errors('update vm') do
        attrs = attrs.empty? ? {} : attrs.first
        data = client({ 'name' => tf_state.name }.merge(attrs)).run('create')
        ComputeVM.new(self, data)
      end
    end

    def test_connection(options = {})
      super
      begin
        client.run('test_connection')
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
