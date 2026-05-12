module ForemanOpentofu
  class KeyPairs < Array
    attr_accessor :opentofu_executer

    def initialize(exec, init_value = [])
      self.opentofu_executer = exec
      super init_value unless init_value.nil?
    end

    def create(opts = {})
      # client.key_pairs.create :name => "foreman-#{id}#{Foreman.uuid}"
      key_pair = TofuKeyPair.new opts[:name]
      key_pair.generate

      opentofu_executer.run_create_key(key_pair)

      key_pair
    end

    def get(name)
      kp = TofuKeyPair.new name
      kp.opentofu_executer = opentofu_executer
      kp
    end
  end
end
