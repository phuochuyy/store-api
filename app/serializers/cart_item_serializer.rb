class CartItemSerializer
  def initialize(cart_item)
    @cart_item = cart_item
  end

  def as_json
    {
      id: @cart_item.id,
      cart_id: @cart_item.cart_id,
      product_id: @cart_item.product_id,
      quantity: @cart_item.quantity,
      unit_price: @cart_item.unit_price.to_f,
      total_price: @cart_item.total_price.to_f,
      product: @cart_item.product ? ProductSerializer.new(@cart_item.product).as_json : nil,
      created_at: @cart_item.created_at&.iso8601,
      updated_at: @cart_item.updated_at&.iso8601
    }
  end
end
