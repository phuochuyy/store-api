class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_methods do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true, null: false
      t.string :gateway_type # stripe, paypal, bank_transfer, etc.
      t.json :gateway_config # Store gateway-specific configuration
      t.decimal :processing_fee_percentage, precision: 5, scale: 2, default: 0.0
      t.decimal :processing_fee_fixed, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :payment_methods, :name, unique: true
    add_index :payment_methods, :is_active
    add_index :payment_methods, :gateway_type
  end
end
