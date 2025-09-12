FactoryBot.define do
  factory :phone do
    name { Faker::Device.model_name }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    price { Faker::Commerce.price(range: 100..2000) }
    stock_quantity { Faker::Number.between(from: 0, to: 100) }
    association :brand
    association :category

    trait :available do
      stock_quantity { Faker::Number.between(from: 1, to: 100) }
    end

    trait :out_of_stock do
      stock_quantity { 0 }
    end

    trait :expensive do
      price { Faker::Commerce.price(range: 1000..3000) }
    end
  end
end
