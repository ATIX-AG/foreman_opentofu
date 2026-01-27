FactoryBot.define do
  factory :tf_state, class: 'ForemanOpentofu::TfState' do
    sequence(:name) { |n| "vm-#{n}" }
    sequence(:uuid) { |n| "uuid-#{n}" }
    state { '{"foo":"bar"}' }
  end
end
