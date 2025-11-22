FactoryBot.define do
  factory :stock_alert do
    product
    alert_type { 'low_stock' }
    threshold { 10 }
    current_stock { 5 }
    status { 'active' }
    triggered_at { Time.current }
    notification_sent { false }

    trait :out_of_stock do
      alert_type { 'out_of_stock' }
      threshold { 0 }
      current_stock { 0 }
    end

    trait :critical do
      alert_type { 'critical_stock' }
      threshold { 5 }
      current_stock { 3 }
    end

    trait :resolved do
      status { 'resolved' }
      resolved_at { Time.current }
    end
  end
end
