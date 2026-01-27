FactoryBot.modify do
  factory :compute_resource do
    provider { 'Tofu' }

    trait :opentofu_nutanix do
      opentofu_provider { :nutanix }
      user { 'nuser' }
      password { 'npassword' }
      sequence(:url) { |n| "#{n}.example.com" }
      # uuid { 'vdatacenter' } # alias for datacenter
      # after(:build) { |cr| cr.stubs(:update_public_key) }
    end

    trait :opentofu_ovirt do
      opentofu_provider { :ovirt }
      user { 'ovuser' }
      password { 'ovpassword' }
      sequence(:url) { |n| "#{n}.example.com" }
    end
  end
end

FactoryBot.define do
  factory :opentofu_nutanix_cr, parent: :compute_resource, class: ForemanOpentofu::Tofu, traits: [:opentofu_nutanix]
  factory :opentofu_ovirt_cr, parent: :compute_resource, class: ForemanOpentofu::Tofu, traits: [:opentofu_ovirt]
end
