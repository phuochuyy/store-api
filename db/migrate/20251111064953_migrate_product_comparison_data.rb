class MigrateProductComparisonData < ActiveRecord::Migration[8.0]
  def up
    # Migrate existing product_ids data to junction table
    ProductComparison.find_each do |comparison|
      next if comparison.product_ids.blank?
      
      product_ids = comparison.product_ids_array
      next if product_ids.empty?
      
      # Only migrate if junction table is empty (avoid duplicates)
      next if comparison.product_comparison_items.any?
      
      product_ids.each_with_index do |product_id, index|
        # Verify product exists
        next unless Product.exists?(product_id)
        
        ProductComparisonItem.create!(
          product_comparison_id: comparison.id,
          product_id: product_id,
          position: index,
          created_at: comparison.created_at,
          updated_at: comparison.updated_at
        )
      end
    end
  end

  def down
    # This migration is data migration, no need to reverse
    # Data will remain in junction table
  end
end
