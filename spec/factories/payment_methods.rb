FactoryBot.define do
  factory :payment_method do
    sequence(:name) { |n| "Payment Method #{n}" }
    description { 'Credit card payment method' }
    gateway_type { 'stripe' }
    is_active { true }
    processing_fee_percentage { 2.5 }
    processing_fee_fixed { 0.0 }
    gateway_config { { api_key: 'test_key' } }

    trait :paypal do
      name { 'PayPal' }
      gateway_type { 'paypal' }
    end

    trait :bank_transfer do
      name { 'Bank Transfer' }
      gateway_type { 'bank_transfer' }
      processing_fee_percentage { 0 }
    end

    trait :cash_on_delivery do
      name { 'Cash on Delivery' }
      gateway_type { 'cash_on_delivery' }
      processing_fee_percentage { 0 }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
