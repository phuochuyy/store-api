class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_quantity, default: 0, null: false
      t.boolean :is_active, default: true, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    # Note: product_id index is automatically created by t.references above
    add_index :product_variants, :sku, unique: true
    add_index :product_variants, :is_active
    add_index :product_variants, [:product_id, :position]
  end
end
