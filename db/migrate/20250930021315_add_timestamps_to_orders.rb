class AddTimestampsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :confirmed_at, :datetime
    add_column :orders, :cancelled_at, :datetime
    add_column :orders, :cancellation_reason, :text
  end
end
