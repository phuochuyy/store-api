class CreatePaymentHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_histories do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :action, null: false
      t.string :previous_status
      t.string :new_status
      t.decimal :amount, precision: 10, scale: 2
      t.string :transaction_id
      t.text :gateway_response
      t.string :performed_by
      t.datetime :performed_at, null: false
      t.text :notes
      t.json :metadata

      t.timestamps
    end

    add_index :payment_histories, :action
    add_index :payment_histories, :previous_status
    add_index :payment_histories, :new_status
    add_index :payment_histories, :performed_at
    add_index :payment_histories, :performed_by
    add_index :payment_histories, [:payment_id, :performed_at]
    add_index :payment_histories, [:action, :performed_at]
  end
end
