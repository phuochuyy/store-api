FactoryBot.define do
  factory :stock_movement do
    product
    user
    movement_type { 'order_created' }
    quantity { -5 }
    previous_quantity { 100 }
    new_quantity { 95 }
    reason { 'Order created' }

    trait :stock_added do
      movement_type { 'order_cancelled' }
      quantity { 5 }
      previous_quantity { 95 }
      new_quantity { 100 }
    end
  end
end
