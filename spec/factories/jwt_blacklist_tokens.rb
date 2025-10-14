FactoryBot.define do
  factory :jwt_blacklist_token do
    token { SecureRandom.urlsafe_base64(32) }
    expires_at { 1.hour.from_now }
    user_id { nil }
    token_type { 'access' }
    reason { nil }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :with_custom_token do
      sequence(:token) { |n| "custom-token-#{n}" }
    end

    trait :refresh_token do
      token_type { 'refresh' }
    end

    trait :with_user do
      user_id { create(:user).id.to_s }
    end
  end
end
