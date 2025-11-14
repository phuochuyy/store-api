FactoryBot.define do
  factory :coupon do
    discount
    code { "COUPON#{SecureRandom.hex(6).upcase}" }
    status { 'active' }
    discount_amount { 0 }

    trait :used do
      status { 'used' }
      used_at { Time.current }
      user
      order
    end

    trait :expired do
      status { 'expired' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end
  end
end

