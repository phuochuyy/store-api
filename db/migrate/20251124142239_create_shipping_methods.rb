class CreateShippingMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_methods do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :base_cost, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :handling_fee, precision: 10, scale: 2, default: 0.0, null: false
      t.boolean :is_active, default: true, null: false
      t.integer :estimated_days, default: 3, null: false

      t.timestamps
    end

    add_index :shipping_methods, :name, unique: true
    add_index :shipping_methods, :is_active
  end
end
