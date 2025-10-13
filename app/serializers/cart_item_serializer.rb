class CartItemSerializer
  include JSONAPI::Serializer

  attributes :id, :cart_id, :product_id, :quantity, :unit_price, :created_at, :updated_at

  attribute :total_price, &:total_price

  attribute :product do |cart_item|
    ProductSerializer.new(cart_item.product).serializable_hash[:data]
  end

  belongs_to :product, serializer: ProductSerializer
end
