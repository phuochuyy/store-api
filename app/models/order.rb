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
  belongs_to :discount, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_many :payments, dependent: :destroy
  has_many :coupons, dependent: :nullify

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: {
    in: %w[pending confirmed shipped delivered cancelled paid payment_failed refunded partially_refunded]
  }
  
  # Validate discount consistency
  validate :discount_code_matches_discount_id, if: -> { discount_id.present? && discount_code.present? }
  
  private
  
  def discount_code_matches_discount_id
    return unless discount_id.present? && discount_code.present?
    
    discount = Discount.find_by(id: discount_id)
    if discount.nil?
      errors.add(:discount_id, 'does not exist')
    elsif discount.code.upcase != discount_code.upcase
      errors.add(:discount_code, 'does not match the selected discount')
    end
  end

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

  scope :recent, -> { order(created_at: :desc) }

  # Default ordering
  default_scope -> { order(created_at: :desc) }

  def update_total_amount
    subtotal = order_items.sum(&:total_price)
    final_total = subtotal - (discount_amount || 0)
    update!(total_amount: final_total, discount_amount: discount_amount || 0)
  end

  def subtotal_amount
    order_items.sum(&:total_price)
  end

  def final_amount
    subtotal_amount - (discount_amount || 0)
  end

  def discount?
    discount_amount.present? && discount_amount.positive?
  end

  def apply_discount(discount_code)
    discount = Discount.available.find_by(code: discount_code.upcase)
    return { success: false, error: 'Invalid discount code' } unless discount

    unless discount.meets_minimum_amount?(subtotal_amount)
      return { success: false,
               error: 'Discount does not meet minimum amount requirement' }
    end

    unless discount.applies_to_items?(order_items)
      return { success: false,
               error: 'Discount does not apply to items in this order' }
    end

    # Calculate discount amount
    calculated_discount = discount.calculate_discount(subtotal_amount)
    return { success: false, error: 'No discount applicable' } if calculated_discount <= 0

    # Apply discount
    update!(
      discount: discount,
      discount_code: discount.code,
      discount_amount: calculated_discount
    )

    update_total_amount

    { success: true, discount_amount: calculated_discount, discount: discount }
  end

  def remove_discount
    update!(
      discount: nil,
      discount_code: nil,
      discount_amount: 0
    )
    update_total_amount
    { success: true }
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

    status_mapping = {
      paid: 'paid',
      payment_failed: 'payment_failed',
      refunded: 'refunded',
      partially_refunded: 'partially_refunded'
    }

    status_mapping.each do |method, status|
      return status if send(method)
    end

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

  # Order status validation methods
  def can_be_confirmed?
    pending?
  end

  def can_be_cancelled?
    %w[pending confirmed shipped].include?(status)
  end

  def can_be_shipped?
    confirmed?
  end

  def can_be_delivered?
    shipped?
  end

  # Order confirmation methods
  def confirmed?
    status == 'confirmed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def shipped?
    status == 'shipped'
  end

  def delivered?
    status == 'delivered'
  end

  # Shipping and delivery methods
  def tracking_info?
    tracking_number.present? || carrier.present?
  end

  def tracking_info
    {
      tracking_number: tracking_number,
      carrier: carrier,
      shipped_at: shipped_at
    }
  end

  def delivery_info
    {
      delivered_at: delivered_at,
      delivery_notes: delivery_notes,
      delivery_signature: delivery_signature
    }
  end

  def shipping_status
    return 'not_shipped' unless shipped?
    return 'delivered' if delivered?

    'in_transit'
  end

  def estimated_delivery_date
    return nil unless shipped_at

    # Simple estimation: 3-5 business days after shipping
    shipped_at + 4.days
  end
end
