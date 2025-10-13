class CartSerializer
  include JSONAPI::Serializer

  attributes :id, :user_id, :session_id, :status, :total_amount, :created_at, :updated_at

  attribute :total_items, &:total_items

  attribute :cart_items do |cart|
    CartItemSerializer.new(cart.cart_items.includes(:product)).serializable_hash[:data]
  end

  has_many :cart_items, serializer: CartItemSerializer
end
