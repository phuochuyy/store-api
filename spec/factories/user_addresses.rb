FactoryBot.define do
  factory :user_address do
    association :user
    full_name { 'John Doe' }
    phone { '+1234567890' }
    address_line1 { '123 Main St' }
    address_line2 { 'Apt 4B' }
    city { 'Ho Chi Minh' }
    state { 'HCMC' }
    postal_code { '70000' }
    country { 'VN' }
    address_type { 'shipping' }
    is_default { false }

    trait :default do
      is_default { true }
    end

    trait :billing do
      address_type { 'billing' }
    end

    trait :shipping do
      address_type { 'shipping' }
    end
  end
end

