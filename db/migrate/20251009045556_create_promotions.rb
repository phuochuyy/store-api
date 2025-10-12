class CreatePromotions < ActiveRecord::Migration[8.0]
  def change
    create_table :promotions do |t|
      t.string :name, null: false
      t.text :description
      t.string :promotion_type, null: false # 'bulk_pricing', 'buy_x_get_y', 'free_gift', 'shipping_discount'
      t.json :conditions # Store complex conditions
      t.json :benefits # Store benefits/offers
      t.datetime :start_date
      t.datetime :end_date
      t.boolean :is_active, default: true
      t.integer :usage_limit
      t.integer :used_count, default: 0
      t.string :priority, default: 'normal' # 'high', 'normal', 'low'
      t.boolean :stackable, default: false # Can be combined with other promotions

      t.timestamps
    end

    add_index :promotions, :promotion_type
    add_index :promotions, :is_active
    add_index :promotions, [:start_date, :end_date]
    add_index :promotions, :priority
  end
end
