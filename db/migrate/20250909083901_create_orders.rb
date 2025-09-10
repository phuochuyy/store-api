class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :customer_name
      t.string :customer_email
      t.string :customer_phone
      t.decimal :total_amount, precision: 10, scale: 2
      t.string :status

      t.timestamps
    end
  end
end
