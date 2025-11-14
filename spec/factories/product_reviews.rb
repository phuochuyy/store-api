FactoryBot.define do
  factory :product_review do
    user
    product
    rating { 5 }
    content { 'Great product!' }
    status { 'approved' }
    verified_purchase { false }
    helpful_count { 0 }

    trait :pending do
      status { 'pending' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :verified do
      verified_purchase { true }
    end
  end
end

