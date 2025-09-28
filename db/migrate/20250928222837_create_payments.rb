class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.string :transaction_id
      t.text :gateway_response
      t.datetime :processed_at
      t.string :failure_reason
      t.json :metadata # Store additional payment data
      t.string :currency, default: 'USD', null: false

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :transaction_id, unique: true
    add_index :payments, :processed_at
    add_index :payments, [:order_id, :status]
  end
end
