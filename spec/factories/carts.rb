FactoryBot.define do
  factory :cart do
    sequence(:session_id) { |n| "session_#{n}" }
    status { 'active' }
    total_amount { 0.0 }
    user

    trait :abandoned do
      status { 'abandoned' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :without_user do
      user { nil }
      session_id { SecureRandom.uuid }
    end
  end
end
