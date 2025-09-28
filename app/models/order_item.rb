# == Schema Information
#
# Table name: order_items
#
#  id         :integer          not null, primary key
#  order_id   :integer          not null
#  product_id :integer          not null
#  quantity   :integer
#  unit_price :decimal(10, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_order_items_on_order_id  (order_id)
#  index_order_items_on_product_id  (product_id)
#

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_unit_price_from_product, if: -> { unit_price.nil? && product.present? }
  after_create :update_order_total
  after_update :update_order_total
  after_destroy :update_order_total

  def total_price
    quantity * unit_price
  end

  private

  def set_unit_price_from_product
    self.unit_price = product.price
  end

  def update_order_total
    order.update_total_amount
  end
end
