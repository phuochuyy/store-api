# == Schema Information
#
# Table name: cart_items
#
#  id         :integer          not null, primary key
#  cart_id    :integer          not null
#  product_id :integer          not null
#  quantity   :integer          not null, default(1)
#  unit_price :decimal(10, 2)   not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  # Uniqueness should include variant if present
  validates :product_id, uniqueness: {
    scope: [:cart_id, :product_variant_id],
    message: 'Product with same variant already in cart'
  }
  validate :variant_belongs_to_product, if: -> { product_variant.present? }

  before_validation :set_unit_price_from_variant_or_product, if: -> { unit_price.nil? }
  after_create :update_cart_total
  after_update :update_cart_total
  after_destroy :update_cart_total

  def total_price
    quantity * unit_price
  end

  def increment_quantity(amount = 1)
    self.quantity += amount
    save!
  end

  def decrement_quantity(amount = 1)
    self.quantity -= amount
    if quantity <= 0
      destroy
    else
      save!
    end
  end

  def variant_display_name
    return product.name unless product_variant
    product_variant.variant_display_name
  end

  private

  def set_unit_price_from_variant_or_product
    if product_variant.present?
      self.unit_price = product_variant.price
    elsif product.present?
      self.unit_price = product.price
    end
  end

  def variant_belongs_to_product
    return unless product_variant && product

    unless product_variant.product_id == product.id
      errors.add(:product_variant, 'must belong to the selected product')
    end
  end

  def update_cart_total
    cart.calculate_total_amount
  end
end
