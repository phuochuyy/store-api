FactoryBot.define do
  factory :promotion do
    name { 'Test Promotion' }
    description { 'A test promotion' }
    promotion_type { 'bulk_pricing' }
    is_active { true }
    priority { 'normal' }
    stackable { false }
    used_count { 0 }
    conditions { { minimum_amount: 100 }.to_json }
    benefits { { tiers: [{ min_quantity: 5, discount_type: 'percentage', discount_value: 10 }] }.to_json }

    trait :buy_x_get_y do
      promotion_type { 'buy_x_get_y' }
      benefits { { buy_quantity: 2, get_quantity: 1 }.to_json }
    end

    trait :free_gift do
      promotion_type { 'free_gift' }
      benefits { { gift_product_id: 1, gift_quantity: 1 }.to_json }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
