# frozen_string_literal: true

FactoryBot.define do
  factory :payment_method do
    sequence(:name) { |n| "Test Payment Method #{n}" }
    description { 'A test payment method for testing purposes' }
    gateway_type { 'stripe' }
    processing_fee_percentage { 2.9 }
    processing_fee_fixed { 0.30 }
    is_active { true }
    gateway_config do
      {
        publishable_key: 'pk_test_1234567890',
        secret_key: 'sk_test_1234567890'
      }
    end

    trait :stripe do
      sequence(:name) { |n| "Credit Card (Stripe) #{n}" }
      gateway_type { 'stripe' }
      processing_fee_percentage { 2.9 }
      processing_fee_fixed { 0.30 }
      gateway_config do
        {
          publishable_key: 'pk_test_1234567890',
          secret_key: 'sk_test_1234567890',
          webhook_secret: 'whsec_1234567890'
        }
      end
    end

    trait :paypal do
      sequence(:name) { |n| "PayPal #{n}" }
      gateway_type { 'paypal' }
      processing_fee_percentage { 3.4 }
      processing_fee_fixed { 0.35 }
      gateway_config do
        {
          client_id: 'paypal_client_id_123',
          client_secret: 'paypal_client_secret_123',
          environment: 'sandbox'
        }
      end
    end

    trait :bank_transfer do
      sequence(:name) { |n| "Bank Transfer #{n}" }
      gateway_type { 'bank_transfer' }
      processing_fee_percentage { 0.0 }
      processing_fee_fixed { 0.0 }
      gateway_config do
        {
          bank_account: '1234567890',
          routing_number: '021000021',
          account_name: 'Test Account'
        }
      end
    end

    trait :cash_on_delivery do
      sequence(:name) { |n| "Cash on Delivery #{n}" }
      gateway_type { 'cash_on_delivery' }
      processing_fee_percentage { 0.0 }
      processing_fee_fixed { 0.0 }
      gateway_config do
        {
          delivery_fee: 5.00,
          instructions: 'Payment will be collected upon delivery'
        }
      end
    end

    trait :wallet do
      sequence(:name) { |n| "Digital Wallet #{n}" }
      gateway_type { 'wallet' }
      processing_fee_percentage { 1.5 }
      processing_fee_fixed { 0.25 }
      gateway_config do
        {
          wallet_provider: 'generic',
          api_key: 'wallet_api_key_123',
          api_secret: 'wallet_api_secret_123'
        }
      end
    end

    trait :inactive do
      is_active { false }
    end
  end
end
