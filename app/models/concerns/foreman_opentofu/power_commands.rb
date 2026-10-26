module ForemanOpentofu
  module PowerCommands
    def start_vm(name)
      change_vm_power(name, :on)
    end

    def stop_vm(name)
      change_vm_power(name, :off)
    end

    private

    def change_vm_power(identifier, action)
      vm_command_errors('change power') do
        tf_state = power_state_record(identifier)
        output = power_state_output(tf_state)

        power_manager = PowerTranslator.new(tofu_provider)
        target_value = power_manager.action_value(action)

        arguments = ComputeVM.new(self, output).to_h
        arguments[power_manager.attribute_name] = target_value
        arguments['name'] = tf_state.name

        result = client(arguments.merge!({ 'power_state' => action.to_s })).run_create(power_only: true)
        verify_power_result(result, action)
      end
    end

    def verify_power_result(result, target_action)
      vm = ComputeVM.new(self, result)
      raise "OpenTofu did not return the requested power state for action #{target_action}" unless vm.power.to_s == target_action.to_s
      vm
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
  end
end
