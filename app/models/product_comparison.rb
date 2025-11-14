class ProductComparison < ApplicationRecord
  belongs_to :user
  has_many :product_comparison_items, dependent: :destroy
  has_many :products, through: :product_comparison_items

  validates :product_ids, presence: true, if: -> { product_comparison_items.empty? }

  # Parse product_ids from text/JSON (backward compatibility)
  def product_ids_array
    # Use junction table if available
    return product_comparison_items.ordered.pluck(:product_id) if product_comparison_items.any?
    
    # Fallback to old product_ids field
    return [] if product_ids.blank?

    if product_ids.is_a?(Array)
      product_ids
    elsif product_ids.is_a?(String)
      begin
        JSON.parse(product_ids)
      rescue JSON::ParserError
        product_ids.split(',').map(&:strip).map(&:to_i)
      end
    else
      []
    end
  end

  # Set product_ids from array (backward compatibility)
  def product_ids_array=(ids)
    ids = ids.is_a?(Array) ? ids : [ids]
    ids = ids.map(&:to_i).reject(&:zero?)
    
    # Use junction table if available
    if product_comparison_items.any? || !product_ids.present?
      # Clear existing items
      product_comparison_items.destroy_all
      
      # Create new items
      ids.each_with_index do |product_id, index|
        product_comparison_items.create!(
          product_id: product_id,
          position: index
        )
      end
    else
      # Fallback to old product_ids field
      self.product_ids = ids.to_json
    end
  end
  
  # Add product to comparison
  def add_product(product, position: nil)
    return false if products.include?(product)
    
    position ||= product_comparison_items.count
    product_comparison_items.create!(
      product: product,
      position: position
    )
  end
  
  # Remove product from comparison
  def remove_product(product)
    product_comparison_items.where(product: product).destroy_all
  end
  
  # Get products in order
  def products_ordered
    products.joins(:product_comparison_items)
           .order('product_comparison_items.position ASC, product_comparison_items.created_at ASC')
  end
end

