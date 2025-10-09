FactoryBot.define do
  factory :jwt_blacklist_token do
    token do
      "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJpYXQiOjE2MzQwNzIwMDAsImV4cCI6MTYzNDE1ODQwMH0.#{SecureRandom.hex(32)}"
    end
    expires_at { 24.hours.from_now }
    user_id { '1' }
    token_type { 'access' }
    reason { 'User logout' }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :refresh_token do
      token_type { 'refresh' }
    end

    trait :password_reset_token do
      token_type { 'password_reset' }
      expires_at { 1.hour.from_now }
    end

    trait :email_verification_token do
      token_type { 'email_verification' }
      expires_at { 24.hours.from_now }
    end
  end
end
