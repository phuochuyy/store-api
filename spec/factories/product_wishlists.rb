FactoryBot.define do
  factory :product_wishlist do
    user
    product
    notes { nil }
    priority { 0 }
  end
end

