class AddDiscountToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :discount_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :orders, :discount_code, :string
    add_reference :orders, :discount, null: true, foreign_key: true
    
    add_index :orders, :discount_code
  end
end
