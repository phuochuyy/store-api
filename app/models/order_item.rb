class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :phone

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }

  def total_price
    quantity * unit_price
  end
end
