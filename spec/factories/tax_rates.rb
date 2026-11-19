FactoryBot.define do
  factory :tax_rate do
    sequence(:name) { |n| "VAT #{n}" }
    country_code { 'VN' }
    tax_rate { 10.0 }
    tax_type { 'VAT' }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
