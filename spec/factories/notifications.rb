FactoryBot.define do
  factory :notification do
    user
    notification_type { 'order_update' }
    title { 'Order Update' }
    message { 'Your order has been updated' }
    read { false }

    trait :read do
      read { true }
      read_at { Time.current }
    end

    trait :stock_alert do
      notification_type { 'stock_alert' }
      title { 'Stock Alert' }
      message { 'A product is running low on stock' }
    end
  end
end
