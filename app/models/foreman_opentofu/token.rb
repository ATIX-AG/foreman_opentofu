module ForemanOpentofu
  class Token < ApplicationRecord
    validates :name, presence: true, uniqueness: true

    def token_expired?
      token_expire <= Time.current
    end

    def generate_token
      self.token_expire = Time.current + Setting[:tfstate_token_timeout]
      self.token = SecureRandom.alphanumeric(255)
    end
  end
end
