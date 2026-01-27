FactoryBot.modify do
  factory :host do
    trait :foreman_opentofu do
      name { 'foreman_opentofu' }
    end
  end
end
