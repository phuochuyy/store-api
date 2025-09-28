# frozen_string_literal: true

FactoryBot.define do
  factory :stock_alert do
    association :product
    alert_type { 'low_stock' }
    threshold { 10 }
    current_stock { 5 }
    status { 'active' }
    triggered_at { Time.current }
    notification_sent { false }
    message { 'Product has low stock level' }

    trait :out_of_stock do
      alert_type { 'out_of_stock' }
      threshold { 0 }
      current_stock { 0 }
      message { 'Product is out of stock' }
    end

    trait :critical_stock do
      alert_type { 'critical_stock' }
      threshold { 5 }
      current_stock { 3 }
      message { 'Product has critical stock level' }
    end

    trait :low_stock do
      alert_type { 'low_stock' }
      threshold { 10 }
      current_stock { 7 }
      message { 'Product has low stock level' }
    end

    trait :reorder_point do
      alert_type { 'reorder_point' }
      threshold { 20 }
      current_stock { 15 }
      message { 'Product has reached reorder point' }
    end

    trait :resolved do
      status { 'resolved' }
      resolved_at { Time.current }
      notification_sent { true }
    end

    trait :dismissed do
      status { 'dismissed' }
      resolved_at { Time.current }
      notification_sent { true }
    end

    trait :notification_sent do
      notification_sent { true }
    end

    trait :with_metadata do
      metadata do
        {
          'resolved_by' => 'admin@example.com',
          'resolution_notes' => 'Stock replenished',
          'resolved_at' => Time.current.iso8601
        }
      end
    end
  end
end
