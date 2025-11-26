class CreateShippingZones < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_zones do |t|
      t.string :name, null: false
      t.string :country_code, null: false
      t.string :region
      t.decimal :base_cost, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :cost_per_kg, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :free_shipping_threshold, precision: 10, scale: 2

      t.timestamps
    end

    add_index :shipping_zones, :country_code
    add_index :shipping_zones, [:country_code, :region]
  end
end
