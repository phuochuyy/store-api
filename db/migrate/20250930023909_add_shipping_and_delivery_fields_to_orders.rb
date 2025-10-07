class AddShippingAndDeliveryFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :tracking_number, :string
    add_column :orders, :carrier, :string
    add_column :orders, :shipped_at, :datetime
    add_column :orders, :delivered_at, :datetime
    add_column :orders, :delivery_notes, :text
    add_column :orders, :delivery_signature, :string
  end
end
