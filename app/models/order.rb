class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :phones, through: :order_items

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending confirmed shipped delivered cancelled] }

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled"
  }

  def update_total_amount
    total = order_items.sum(&:total_price)
    update_column(:total_amount, total)
  end
end
