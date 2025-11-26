class AddShippingFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :shipping_method, foreign_key: true, index: true
    add_column :orders, :shipping_cost, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :orders, :shipping_address, :text
    add_column :orders, :shipping_weight, :decimal, precision: 10, scale: 2
  end
end
