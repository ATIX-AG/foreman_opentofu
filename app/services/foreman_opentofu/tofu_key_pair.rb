module ForemanOpentofu
  class TofuKeyPair
    attr_reader :name, :public_key, :private_key
    attr_accessor :opentofu_executer

    def initialize(name)
      @name = name
      @keypair = KeyPair.find_by name: name
      @public_key = @keypair&.public
      @private_key = @keypair&.secret
    end

    def generate
      key = OpenSSL::PKey::RSA.generate(Setting[:tofu_ssh_key_bits])
      @private_key = key.private_to_pem
      @public_key = "#{key.ssh_type} #{[key.to_blob].pack('m0')}"
    end

    def destroy
      opentofu_executer.run_destroy_key(self)
      @keypair.try :destroy
    end
  end
end
