class CreateProductComparisonItems < ActiveRecord::Migration[8.0]
  def change
    create_table :product_comparison_items do |t|
      t.bigint :product_comparison_id, null: false
      t.bigint :product_id, null: false
      t.integer :position, default: 0
      t.timestamps
      
      t.index [:product_comparison_id, :product_id], unique: true, name: 'index_pci_on_comparison_and_product'
      t.index :product_comparison_id
      t.index :product_id
      t.index :position
    end
    
    add_foreign_key :product_comparison_items, :product_comparisons, on_delete: :cascade
    add_foreign_key :product_comparison_items, :products, on_delete: :cascade
  end
end
