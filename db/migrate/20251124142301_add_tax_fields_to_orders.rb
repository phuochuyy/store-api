class AddTaxFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :tax_rate, foreign_key: true, index: true
    add_column :orders, :tax_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :orders, :tax_rate_value, :decimal, precision: 5, scale: 2
  end
end
