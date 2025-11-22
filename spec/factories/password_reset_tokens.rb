FactoryBot.define do
  factory :password_reset_token do
    user
    token { SecureRandom.urlsafe_base64(32) }
    expires_at { 1.hour.from_now }
    used { false }

    trait :used do
      used { true }
      used_at { Time.current }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
