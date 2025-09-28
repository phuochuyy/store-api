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

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :product_id, uniqueness: { scope: :cart_id }

  before_validation :set_unit_price_from_product, if: -> { unit_price.nil? && product.present? }
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

  private

  def set_unit_price_from_product
    self.unit_price = product.price
  end

  def update_cart_total
    cart.calculate_total_amount
  end
end
