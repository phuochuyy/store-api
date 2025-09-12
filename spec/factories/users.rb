FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password" }
    password_confirmation { "password" }
    role { "customer" }

    trait :admin do
      role { "admin" }
    end

    trait :customer do
      role { "customer" }
    end
  end
end
