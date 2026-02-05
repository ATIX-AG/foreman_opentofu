FactoryBot.define do
  factory :foreman_opentofu_token, class: 'ForemanOpentofu::Token' do
    sequence(:name) { |n| "vm-#{n}" }
    sequence(:token) { |n| "secret#{n}" }
    token_expire { Time.current + 3600 }
    trait :token_expired do
      token_expire { Time.current - 3600 }
    end
  end
end
