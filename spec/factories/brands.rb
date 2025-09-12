FactoryBot.define do
  factory :brand do
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph(sentence_count: 2) }
  end
end
