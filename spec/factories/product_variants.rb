FactoryBot.define do
  factory :product_variant do
    product
    sequence(:name) { |n| "Variant #{n}" }
    sequence(:sku) { |n| "SKU-#{n}" }
    price { 109.99 }
    stock_quantity { 10 }
    is_active { true }
  end
end
