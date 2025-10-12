class CreateDiscounts < ActiveRecord::Migration[8.0]
  def change
    create_table :discounts do |t|
      t.string :name, null: false
      t.text :description
      t.string :discount_type, null: false # 'percentage', 'fixed_amount', 'free_shipping'
      t.decimal :value, precision: 10, scale: 2, null: false
      t.decimal :minimum_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :maximum_discount, precision: 10, scale: 2
      t.integer :usage_limit
      t.integer :used_count, default: 0
      t.datetime :start_date
      t.datetime :end_date
      t.boolean :is_active, default: true
      t.string :code, null: false
      t.json :conditions # Store complex conditions like product_ids, category_ids
      t.string :applies_to, default: 'all' # 'all', 'products', 'categories', 'brands'
      t.text :applies_to_ids # Comma-separated IDs

      t.timestamps
    end

    add_index :discounts, :code, unique: true
    add_index :discounts, :discount_type
    add_index :discounts, :is_active
    add_index :discounts, [:start_date, :end_date]
  end
end
