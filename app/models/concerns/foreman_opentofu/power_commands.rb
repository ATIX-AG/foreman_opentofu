module ForemanOpentofu
  module PowerCommands
    def start_vm(name)
      return change_vm_power(name, 'on') if tofu_provider.respond_to?(:power_state_attributes)

      output = client({ 'name' => name, 'power_state' => 'on' }).run_create
      output['vm']['power_state'] == 'on'
    end

    def stop_vm(name)
      return change_vm_power(name, 'off') if tofu_provider.respond_to?(:power_state_attributes)

      output = client({ 'name' => name, 'power_state' => 'off' }).run_create
      output['vm']['power_state'] == 'off'
    end

    private

    def change_vm_power(identifier, state)
      vm_command_errors('change power') do
        tf_state = power_state_record(identifier)
        output = power_state_output(tf_state)
        result = client(power_state_arguments(output, tf_state.name, state)).run_create(power_only: true)
        verify_power_result(result, state)
      end
    end

    def power_state_record(identifier)
      tf_state = TfState.find_by(uuid: identifier) || TfState.find_by(name: identifier)
      raise "No OpenTofu state found for #{identifier}" unless tf_state

      tf_state
    end

    def power_state_output(tf_state)
      output = client('name' => tf_state.name).run_output
      valid = output['vm'].is_a?(Hash) && output['vm'].present?
      raise 'Power control requires VM output from the provisioning template.' unless valid

      output
    end

    def power_state_arguments(output, name, state)
      arguments = ComputeVM.new(self, output).to_h
      arguments.merge!(tofu_provider.power_state_attributes(state))
      arguments['name'] = name
      arguments
    end

    def verify_power_result(result, state)
      vm = ComputeVM.new(self, result)
      raise "OpenTofu did not return the requested power state #{state}" unless vm.power == state

      vm
    end
  end
end
