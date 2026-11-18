FactoryBot.define do
  factory :cart do
    user
    sequence(:session_id) { |n| "session-#{n}" }
    status { 'active' }

    trait :guest do
      user { nil }
    end
  end
end
