FactoryBot.define do
  factory :discount do
    name { 'Test Discount' }
    description { 'A test discount description' }
    discount_type { 'percentage' }
    value { 10.0 }
    code { "DISC#{SecureRandom.hex(4).upcase}" }
    is_active { true }
    applies_to { 'all' }

    trait :percentage do
      discount_type { 'percentage' }
      value { 15.0 }
      maximum_discount { 50.0 }
    end

    trait :fixed_amount do
      discount_type { 'fixed_amount' }
      value { 20.0 }
    end

    trait :free_shipping do
      discount_type { 'free_shipping' }
      value { 0 }
    end

    trait :inactive do
      is_active { false }
    end

    trait :expired do
      start_date { 10.days.ago }
      end_date { 5.days.ago }
    end

    trait :future do
      start_date { 5.days.from_now }
      end_date { 10.days.from_now }
    end
  end
end

