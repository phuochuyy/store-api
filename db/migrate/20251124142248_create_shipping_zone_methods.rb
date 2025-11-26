class CreateShippingZoneMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_zone_methods do |t|
      t.references :shipping_zone, null: false, foreign_key: true
      t.references :shipping_method, null: false, foreign_key: true
      t.decimal :cost_multiplier, precision: 5, scale: 2, default: 1.0, null: false

      t.timestamps
    end

    add_index :shipping_zone_methods, [:shipping_zone_id, :shipping_method_id], unique: true, name: 'index_shipping_zone_methods_unique'
  end
end
