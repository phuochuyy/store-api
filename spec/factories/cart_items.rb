FactoryBot.define do
  factory :cart_item do
    association :cart, factory: :cart
    association :product, factory: :product
    quantity { 1 }
    unit_price { product.price }

    trait :multiple_quantity do
      quantity { 3 }
    end

    trait :with_different_price do
      unit_price { 99.99 }
    end
  end
end
