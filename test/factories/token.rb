FactoryBot.define do
  factory :foreman_opentofu_token, class: 'ForemanOpentofu::Token' do
    sequence(:name) { |n| "vm-#{n}" }
    sequence(:token) { |n| "secret#{n}" }
    expire { Time.current + 3600 }
    trait :expired do
      expire { Time.current - 3600 }
    end
  end
end
