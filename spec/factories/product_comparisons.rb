FactoryBot.define do
  factory :product_comparison do
    user
    product_ids { [] }

    trait :with_products do
      after(:create) do |comparison|
        products = create_list(:product, 3)
        products.each_with_index do |product, index|
          create(:product_comparison_item, product_comparison: comparison, product: product, position: index)
        end
      end
    end
  end
end
