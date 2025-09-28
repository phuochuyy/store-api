FactoryBot.define do
  factory :cart do
    association :user, factory: :user
    session_id { SecureRandom.uuid }
    status { 'active' }
    total_amount { 0.0 }

    trait :with_items do
      after(:create) do |cart|
        create_list(:cart_item, 3, cart: cart)
        cart.calculate_total_amount
      end
    end

    trait :abandoned do
      status { 'abandoned' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :guest_cart do
      user { nil }
      session_id { SecureRandom.uuid }
    end
  end
end
