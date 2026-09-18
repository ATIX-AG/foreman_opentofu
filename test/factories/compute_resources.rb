FactoryBot.modify do
  factory :compute_resource do
    provider { 'Tofu' }

    trait :opentofu_hetzner do
      opentofu_provider { :hetzner }
      user { 'dummy' }
      password { 'apitoken' }
      url { 'dummy' }
    end

    trait :opentofu_nutanix do
      opentofu_provider { :nutanix }
      user { 'nuser' }
      password { 'npassword' }
      sequence(:url) { |n| "#{n}.example.com" }
      # uuid { 'vdatacenter' } # alias for datacenter
      # after(:build) { |cr| cr.stubs(:update_public_key) }
    end
  end
end

FactoryBot.define do
  factory :opentofu_hetzner_cr, parent: :compute_resource, class: ForemanOpentofu::Tofu, traits: [:opentofu_hetzner]
  factory :opentofu_nutanix_cr, parent: :compute_resource, class: ForemanOpentofu::Tofu, traits: [:opentofu_nutanix]
end
