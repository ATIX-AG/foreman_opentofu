module ForemanOpentofu
  class Token < ApplicationRecord
    validates :name, presence: true, uniqueness: true

    def expired?
      !expire.respond_to?(:<=) || (expire <= Time.current)
    end

    def generate
      self.expire = Time.current + Setting[:tfstate_token_timeout]
      self.token = SecureRandom.alphanumeric(255)
      save!
      token
    end
  end
end
