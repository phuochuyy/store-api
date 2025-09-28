# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    association :order
    association :payment_method
    amount { 100.00 }
    currency { 'USD' }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
      transaction_id { "txn_#{SecureRandom.hex(8)}" }
      gateway_response { '{"status": "succeeded", "id": "pi_1234567890"}' }
      processed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      failure_reason { 'Insufficient funds' }
      gateway_response { '{"error": "card_declined", "message": "Your card was declined."}' }
      processed_at { Time.current }
    end

    trait :cancelled do
      status { 'cancelled' }
      failure_reason { 'User cancelled' }
      processed_at { Time.current }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :refunded do
      status { 'refunded' }
      transaction_id { "txn_#{SecureRandom.hex(8)}" }
      gateway_response { '{"refund_id": "re_1234567890", "status": "succeeded"}' }
      processed_at { Time.current }
    end

    trait :partially_refunded do
      status { 'partially_refunded' }
      transaction_id { "txn_#{SecureRandom.hex(8)}" }
      gateway_response { '{"refund_id": "re_1234567890", "status": "succeeded", "amount": 50.00}' }
      processed_at { Time.current }
    end

    trait :with_metadata do
      metadata do
        {
          'customer_ip' => '192.168.1.1',
          'user_agent' => 'Mozilla/5.0...',
          'source' => 'web'
        }
      end
    end

    trait :stripe_payment do
      association :payment_method, :stripe
      transaction_id { "pi_#{SecureRandom.hex(8)}" }
      gateway_response do
        {
          'id' => "pi_#{SecureRandom.hex(8)}",
          'status' => 'succeeded',
          'amount' => (amount * 100).to_i,
          'currency' => currency.downcase
        }.to_json
      end
    end

    trait :paypal_payment do
      association :payment_method, :paypal
      transaction_id { "PAY-#{SecureRandom.hex(8)}" }
      gateway_response do
        {
          'id' => "PAY-#{SecureRandom.hex(8)}",
          'state' => 'approved',
          'amount' => amount,
          'currency' => currency
        }.to_json
      end
    end

    trait :bank_transfer_payment do
      association :payment_method, :bank_transfer
      transaction_id { "bank_#{SecureRandom.hex(8)}" }
      gateway_response do
        {
          'status' => 'pending',
          'instructions' => 'Please transfer the amount to our bank account',
          'reference' => transaction_id
        }.to_json
      end
    end

    trait :cash_on_delivery_payment do
      association :payment_method, :cash_on_delivery
      transaction_id { "cod_#{SecureRandom.hex(8)}" }
      gateway_response do
        {
          'status' => 'pending',
          'instructions' => 'Payment will be collected on delivery'
        }.to_json
      end
    end
  end
end
