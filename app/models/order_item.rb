# == Schema Information
#
# Table name: order_items
#
#  id         :integer          not null, primary key
#  order_id   :integer          not null
#  phone_id   :integer          not null
#  quantity   :integer
#  unit_price :decimal(10, 2)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_order_items_on_order_id  (order_id)
#  index_order_items_on_phone_id  (phone_id)
#

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :phone

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }

  def total_price
    quantity * unit_price
  end
end
