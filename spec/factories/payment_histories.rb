# frozen_string_literal: true

FactoryBot.define do
  factory :payment_history do
    association :payment
    action { 'status_changed' }
    previous_status { 'pending' }
    new_status { 'completed' }
    amount { 100.00 }
    transaction_id { "txn_#{SecureRandom.hex(8)}" }
    gateway_response { '{"status": "succeeded", "id": "pi_1234567890"}' }
    performed_by { 'System' }
    performed_at { Time.current }
    notes { 'Payment status updated' }

    trait :created do
      action { 'created' }
      previous_status { nil }
      new_status { 'pending' }
      notes { 'Payment created' }
    end

    trait :status_changed do
      action { 'status_changed' }
      previous_status { 'pending' }
      new_status { 'completed' }
      notes { 'Status changed from pending to completed' }
    end

    trait :amount_updated do
      action { 'amount_updated' }
      previous_status { nil }
      new_status { nil }
      amount { 150.00 }
      notes { 'Payment amount updated' }
    end

    trait :transaction_updated do
      action { 'transaction_updated' }
      previous_status { nil }
      new_status { nil }
      transaction_id { "txn_#{SecureRandom.hex(8)}" }
      notes { 'Transaction ID updated' }
    end

    trait :refunded do
      action { 'refunded' }
      previous_status { 'completed' }
      new_status { 'refunded' }
      amount { 50.00 }
      notes { 'Partial refund processed' }
    end

    trait :failed do
      action { 'failed' }
      previous_status { 'processing' }
      new_status { 'failed' }
      notes { 'Payment failed due to insufficient funds' }
    end

    trait :cancelled do
      action { 'cancelled' }
      previous_status { 'pending' }
      new_status { 'cancelled' }
      notes { 'Payment cancelled by user' }
    end

    trait :processed do
      action { 'processed' }
      previous_status { 'pending' }
      new_status { 'processing' }
      notes { 'Payment processing started' }
    end

    trait :gateway_response_updated do
      action { 'gateway_response_updated' }
      previous_status { nil }
      new_status { nil }
      gateway_response { '{"status": "succeeded", "id": "pi_1234567890", "amount": 10000}' }
      notes { 'Gateway response updated' }
    end

    trait :metadata_updated do
      action { 'metadata_updated' }
      previous_status { nil }
      new_status { nil }
      notes { 'Payment metadata updated' }
    end

    trait :with_metadata do
      metadata do
        {
          'previous_amount' => 100.00,
          'refund_amount' => 50.00,
          'failure_reason' => 'Insufficient funds',
          'gateway_error_code' => 'card_declined'
        }
      end
    end

    trait :performed_by_admin do
      performed_by { 'admin@example.com' }
    end

    trait :performed_by_user do
      performed_by { 'user@example.com' }
    end

    trait :performed_by_system do
      performed_by { 'System' }
    end

    trait :with_notes do
      notes { 'Detailed notes about this payment history entry' }
    end
  end
end
