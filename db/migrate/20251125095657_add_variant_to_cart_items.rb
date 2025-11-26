class AddVariantToCartItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :cart_items, :product_variant, foreign_key: true
    # Note: product_variant_id index is automatically created by add_reference above
  end
end
