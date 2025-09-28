class RenamePhonesToProducts < ActiveRecord::Migration[8.0]
  def up
    # Rename table
    rename_table :phones, :products
    
    # Rename foreign key columns in other tables
    rename_column :order_items, :phone_id, :product_id
    
    # Update indexes
    remove_index :order_items, :phone_id if index_exists?(:order_items, :phone_id)
    add_index :order_items, :product_id unless index_exists?(:order_items, :product_id)
    
    # Update any existing data if needed
    # (No data transformation needed as structure remains the same)
  end

  def down
    # Reverse the changes
    remove_index :order_items, :product_id if index_exists?(:order_items, :product_id)
    add_index :order_items, :phone_id
    
    rename_column :order_items, :product_id, :phone_id
    rename_table :products, :phones
  end
end