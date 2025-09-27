FactoryBot.define do
  factory :order_item do
    association :order
    association :phone
    quantity { 1 }
    unit_price { 1000.0 }

    trait :multiple_quantity do
      quantity { 3 }
    end

    trait :expensive do
      unit_price { 2000.0 }
    end
  end
end
