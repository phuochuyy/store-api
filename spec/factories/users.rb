FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { 'John' }
    last_name { 'Doe' }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'customer' }

    trait :admin do
      role { 'admin' }
    end

    trait :customer do
      role { 'customer' }
    end

    trait :with_profile do
      first_name { 'John' }
      last_name { 'Doe' }
      phone { '+1234567890' }
      gender { 'male' }
      bio { 'This is a test bio' }
      date_of_birth { 25.years.ago }
    end

    trait :verified do
      email_verified_at { Time.current }
      email_verification_token { nil }
    end

    trait :unverified do
      email_verified_at { nil }
      email_verification_token { SecureRandom.urlsafe_base64(32) }
    end

    trait :with_preferences do
      preferences do
        {
          'notifications' => {
            'email' => true,
            'push' => true,
            'sms' => false
          }
        }
      end
    end
  end
end
