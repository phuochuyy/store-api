class CartSerializer
  def initialize(cart)
    @cart = cart
  end

  def as_json
    {
      id: @cart.id,
      user_id: @cart.user_id,
      session_id: @cart.session_id,
      status: @cart.status,
      total_amount: @cart.total_amount.to_f,
      total_items: @cart.total_items,
      cart_items: @cart.cart_items.includes(:product).map { |item| CartItemSerializer.new(item).as_json },
      created_at: @cart.created_at&.iso8601,
      updated_at: @cart.updated_at&.iso8601
    }
  end
end
