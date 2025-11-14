class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Orders indexes
    add_index :orders, :status unless index_exists?(:orders, :status)
    add_index :orders, :created_at unless index_exists?(:orders, :created_at)
    add_index :orders, [:status, :created_at] unless index_exists?(:orders, [:status, :created_at])
    
    # Products indexes for filtering
    add_index :products, :price unless index_exists?(:products, :price)
    add_index :products, :stock_quantity unless index_exists?(:products, :stock_quantity)
    add_index :products, [:price, :stock_quantity] unless index_exists?(:products, [:price, :stock_quantity])
    
    # Carts indexes
    add_index :carts, :created_at unless index_exists?(:carts, :created_at)
    add_index :carts, [:status, :created_at] unless index_exists?(:carts, [:status, :created_at])
    
    # Payments indexes
    add_index :payments, :created_at unless index_exists?(:payments, :created_at)
    
    # Stock movements indexes
    add_index :stock_movements, :movement_type unless index_exists?(:stock_movements, :movement_type)
  end
end
