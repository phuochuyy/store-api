FactoryBot.define do
  factory :shipping_method do
    sequence(:name) { |n| "Standard Shipping #{n}" }
    description { 'Delivered in 3-5 business days' }
    base_cost { 5.00 }
    handling_fee { 1.00 }
    estimated_days { 3 }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
