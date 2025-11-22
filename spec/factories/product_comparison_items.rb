FactoryBot.define do
  factory :product_comparison_item do
    product_comparison
    product
    position { 0 }
  end
end
