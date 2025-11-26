# frozen_string_literal: true

# == Schema Information
#
# Table name: return_items
#
#  id               :integer          not null, primary key
#  return_request_id :integer          not null
#  order_item_id    :integer          not null
#  quantity         :integer          not null
#  reason           :text
#  condition        :string           default("unopened")
#  refund_amount    :decimal(10, 2)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class ReturnItem < ApplicationRecord
  belongs_to :return_request
  belongs_to :order_item

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :condition, inclusion: {
    in: %w[unopened opened damaged defective]
  }
  validate :quantity_not_exceeding_order_item

  before_save :calculate_refund_amount

  def calculate_refund_amount
    return if refund_amount.present?

    # Calculate refund based on order item price and quantity
    item_total = order_item.unit_price * quantity
    # Apply condition-based refund percentage
    refund_percentage = condition_refund_percentage
    self.refund_amount = (item_total * refund_percentage / 100.0).round(2)
  end

  private

  def quantity_not_exceeding_order_item
    return unless order_item && quantity

    if quantity > order_item.quantity
      errors.add(:quantity, "cannot exceed order item quantity (#{order_item.quantity})")
    end
  end

  def condition_refund_percentage
    case condition
    when 'unopened'
      100
    when 'opened'
      80
    when 'damaged'
      50
    when 'defective'
      100
    else
      0
    end
  end
end

