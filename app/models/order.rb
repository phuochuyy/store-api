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
  belongs_to :user, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_many :payments, dependent: :destroy

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: {
    in: %w[pending confirmed shipped delivered cancelled paid payment_failed refunded partially_refunded]
  }

  enum :status, {
    pending: 'pending',
    confirmed: 'confirmed',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled',
    paid: 'paid',
    payment_failed: 'payment_failed',
    refunded: 'refunded',
    partially_refunded: 'partially_refunded'
  }

  # Scope for recent orders
  scope :recent, -> { order(created_at: :desc) }

  # Default ordering
  default_scope -> { order(created_at: :desc) }

  def update_total_amount
    total = order_items.sum(&:total_price)
    update_column(:total_amount, total)
  end

  def total_items
    order_items.sum(:quantity)
  end

  # Payment-related methods
  def latest_payment
    payments.recent.first
  end

  def successful_payments
    payments.successful
  end

  def total_paid_amount
    successful_payments.sum(:amount)
  end

  def payment_status
    return 'unpaid' if payments.empty?
    return 'paid' if paid?
    return 'payment_failed' if payment_failed?
    return 'refunded' if refunded?
    return 'partially_refunded' if partially_refunded?

    latest_payment&.status || 'pending'
  end

  def can_be_paid?
    %w[pending payment_failed].include?(status)
  end

  def can_be_refunded?
    %w[paid].include?(status) && successful_payments.any?
  end

  def payment_methods_used
    payments.joins(:payment_method).pluck('payment_methods.name').uniq
  end
end
