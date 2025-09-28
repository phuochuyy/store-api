# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :user
    notification_type { 'stock_alert' }
    title { 'Test Notification' }
    message { 'This is a test notification message' }
    read { false }
    metadata { {} }

    trait :read do
      read { true }
      read_at { Time.current }
    end

    trait :unread do
      read { false }
      read_at { nil }
    end

    trait :stock_alert do
      notification_type { 'stock_alert' }
      title { 'Stock Alert: Test Product' }
      message { 'Product has low stock level' }
      metadata do
        {
          stock_alert_id: 1,
          product_id: 1,
          product_name: 'Test Product',
          alert_type: 'low_stock',
          severity_level: 'medium',
          current_stock: 5,
          threshold: 10
        }
      end
    end

    trait :system_alert do
      notification_type { 'system_alert' }
      title { 'System Alert' }
      message { 'System maintenance scheduled' }
      metadata { { alert_type: 'maintenance' } }
    end

    trait :order_update do
      notification_type { 'order_update' }
      title { 'Order Update' }
      message { 'Your order has been shipped' }
      metadata { { order_id: 1, status: 'shipped' } }
    end

    trait :payment_update do
      notification_type { 'payment_update' }
      title { 'Payment Update' }
      message { 'Payment processed successfully' }
      metadata { { payment_id: 1, status: 'completed' } }
    end

    trait :promotion do
      notification_type { 'promotion' }
      title { 'Special Promotion' }
      message { 'Get 20% off on all products' }
      metadata { { discount_percentage: 20, valid_until: 1.week.from_now } }
    end

    trait :with_sent_at do
      sent_at { Time.current }
    end

    trait :pending do
      sent_at { nil }
    end
  end
end
