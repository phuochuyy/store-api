FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { 'This is a test product description that is long enough to meet validation requirements' }
    price { 99.99 }
    stock_quantity { 10 }
    brand
    category
    specifications { '{"color": "black", "storage": "128GB"}' }

    trait :out_of_stock do
      stock_quantity { 0 }
    end

    trait :low_stock do
      stock_quantity { 5 }
    end

    trait :high_stock do
      stock_quantity { 100 }
    end

    trait :expensive do
      price { 1500.00 }
    end

    trait :cheap do
      price { 50.00 }
    end

    trait :with_image do
      after(:create) do |product|
        product.image.attach(
          io: StringIO.new('fake image content'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
