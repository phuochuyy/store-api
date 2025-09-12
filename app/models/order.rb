# == Schema Information
#
# Table name: orders
#
#  id             :integer          not null, primary key
#  customer_name  :string(255)
#  customer_email :string(255)
#  customer_phone :string(255)
#  total_amount   :decimal(10, 2)
#  status         :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :phones, through: :order_items

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :total_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed shipped delivered cancelled] }

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled"
  }

  # Scope for recent orders
  scope :recent, -> { order(created_at: :desc) }

  def update_total_amount
    total = order_items.sum(&:total_price)
    update_column(:total_amount, total)
  end
end
