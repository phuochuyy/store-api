FactoryBot.define do
  factory :order do
    customer_name { 'John Doe' }
    customer_email { 'john@example.com' }
    customer_phone { '1234567890' }
    status { 'pending' }
    total_amount { 0.0 }

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :shipped do
      status { 'shipped' }
    end

    trait :delivered do
      status { 'delivered' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end
  end
end
