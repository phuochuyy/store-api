FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "Brand #{n}" }
    description { 'A test brand description' }
  end
end

