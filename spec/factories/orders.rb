FactoryBot.define do
  factory :order do
    customer_name { 'John Doe' }
    customer_email { 'customer@example.com' }
    customer_phone { '+1234567890' }
    total_amount { 0.0 }
    status { 'pending' }
    user

    trait :with_items do
      after(:build) do |order|
        product = create(:product)
        order.order_items.build(product: product, quantity: 2, unit_price: 100.00)
      end
    end

    trait :confirmed do
      status { 'confirmed' }
      confirmed_at { Time.current }
    end

    trait :shipped do
      status { 'shipped' }
      shipped_at { Time.current }
      tracking_number { 'TRACK123' }
      carrier { 'DHL' }
    end

    trait :delivered do
      status { 'delivered' }
      delivered_at { Time.current }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Time.current }
      cancellation_reason { 'Customer request' }
    end

    trait :paid do
      status { 'paid' }
    end
  end
end

