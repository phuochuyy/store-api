FactoryBot.define do
  factory :payment do
    order
    payment_method
    amount { 100.00 }
    status { 'pending' }
    currency { 'USD' }

    trait :completed do
      status { 'completed' }
      processed_at { Time.current }
      transaction_id { "TXN#{SecureRandom.hex(8).upcase}" }
    end

    trait :failed do
      status { 'failed' }
      failure_reason { 'Insufficient funds' }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :refunded do
      status { 'refunded' }
      processed_at { Time.current }
    end
  end
end

