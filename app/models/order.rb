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
  belongs_to :shipping_method, optional: true
  belongs_to :tax_rate, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_many :payments, dependent: :destroy
  has_many :coupons, dependent: :nullify
  has_many :return_requests, dependent: :destroy

  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed shipped delivered cancelled] }

  # Validate discount consistency
  validate :discount_code_matches_discount_id, if: -> { discount_id.present? && discount_code.present? }

  # Fulfillment and payment are tracked separately: an order can be paid before or after it is
  # confirmed or shipped (cash on delivery), and a refund does not erase how far it got.
  # status only changes through the confirm/ship/deliver/cancel services; payment_status only
  # through Payment (see Payment#sync_order_payment_status).
  enum :status, {
    pending: 'pending',
    confirmed: 'confirmed',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled'
  }, default: :pending

  enum :payment_status, {
    unpaid: 'unpaid',
    paid: 'paid',
    payment_failed: 'payment_failed',
    refunded: 'refunded',
    partially_refunded: 'partially_refunded'
  }, default: :unpaid

  scope :recent, -> { order(created_at: :desc) }

  # Default ordering
  default_scope -> { order(created_at: :desc) }

  def update_total_amount
    subtotal = order_items.sum(&:total_price)
    discount = discount_amount || 0
    shipping = shipping_cost || 0
    tax = tax_amount || 0
    final_total = subtotal - discount + shipping + tax
    update!(
      total_amount: final_total,
      discount_amount: discount,
      shipping_cost: shipping,
      tax_amount: tax
    )
  end

  def subtotal_amount
    order_items.sum(&:total_price)
  end

  def final_amount
    subtotal_amount - (discount_amount || 0) + (shipping_cost || 0) + (tax_amount || 0)
  end

  def discount?
    discount_amount.present? && discount_amount.positive?
  end

  # Order status validation methods (public)
  def can_be_confirmed?
    pending?
  end

  def can_be_cancelled?
    %w[pending confirmed shipped].include?(status)
  end

  def can_be_shipped?
    status == 'confirmed'
  end

  def can_be_delivered?
    status == 'shipped'
  end

  # Shipping and delivery methods (public)
  def shipping_status
    return 'not_shipped' unless shipped?
    return 'delivered' if delivered?
    return 'in_transit' if shipped?

    'unknown'
  end

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

  def estimated_delivery_date
    return nil unless shipped_at

    # Simple estimation: 3-5 business days after shipping
    shipped_at + 4.days
  end

  def delivered?
    status == 'delivered'
  end

  def can_be_returned?
    # Order can be returned if delivered and within return period (typically 30 days)
    return false unless delivered?
    return false if delivered_at.nil?

    return_period = 30.days
    delivered_at + return_period >= Time.current
  end

  # Discount (called from OrdersController)
  DISCOUNT_LOCKED_ERROR = 'Discounts can only change while the order is pending and unpaid'.freeze
  SWITCH_DISCOUNT_ERRORS = { locked: DISCOUNT_LOCKED_ERROR, limit_reached: 'Discount usage limit reached' }.freeze

  # A discount or promotion changes what the customer owes, so it can only change while the order
  # is still being placed: pending, and not paid yet.
  def discount_editable?
    pending? && (unpaid? || payment_failed?)
  end

  def apply_discount(discount_code)
    return { success: false, error: DISCOUNT_LOCKED_ERROR } unless discount_editable?

    discount = Discount.available.find_by(code: discount_code.upcase)
    refusal = discount_refusal(discount)
    return { success: false, error: refusal } if refusal

    calculated_discount = discount.amount_off(subtotal_amount)
    return { success: false, error: 'No discount applicable' } if calculated_discount <= 0

    outcome = with_lock { switch_discount_to(discount, calculated_discount) }
    return { success: false, error: SWITCH_DISCOUNT_ERRORS[outcome] } if SWITCH_DISCOUNT_ERRORS.key?(outcome)

    { success: true, discount_amount: calculated_discount, discount: discount }
  end

  # Gives the discount's use back (see Discount#release_usage!).
  def remove_discount
    removed = with_lock do
      next false unless discount_editable?

      discount&.release_usage!
      update!(discount: nil, discount_code: nil, discount_amount: 0)
      update_total_amount
      true
    end
    removed ? { success: true } : { success: false, error: DISCOUNT_LOCKED_ERROR }
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

  # Any order that is not cancelled can be paid until a payment succeeds, whatever its
  # fulfillment status (cash on delivery is paid after shipping).
  def can_be_paid?
    !cancelled? && (unpaid? || payment_failed?)
  end

  def can_be_refunded?
    paid? && successful_payments.any?
  end

  def payment_methods_used
    payments.joins(:payment_method).pluck('payment_methods.name').uniq
  end

  def cancelled?
    status == 'cancelled'
  end

  def shipped?
    status == 'shipped'
  end

  private

  # Why the code cannot be used on this order, or nil.
  def discount_refusal(discount)
    return 'Invalid discount code' unless discount
    return 'Discount does not meet minimum amount requirement' unless discount.meets_minimum_amount?(subtotal_amount)

    'Discount does not apply to items in this order' unless discount.applies_to_items?(order_items)
  end

  # Runs under the order's row lock, so two requests on the same order cannot both take a use.
  # An order holds at most one use of one discount: re-applying the same code takes nothing, and
  # switching codes gives the previous one back. Returns :locked when the order moved on meanwhile
  # (see #discount_editable?), and :limit_reached when no use is left.
  def switch_discount_to(new_discount, amount)
    return :locked unless discount_editable?

    if discount_id != new_discount.id
      return :limit_reached unless new_discount.claim_usage!

      discount&.release_usage!
    end

    update!(discount: new_discount, discount_code: new_discount.code, discount_amount: amount)
    update_total_amount
    :applied
  end

  def discount_code_matches_discount_id
    return unless discount_id.present? && discount_code.present?

    discount = Discount.find_by(id: discount_id)
    if discount.nil?
      errors.add(:discount_id, 'does not exist')
    elsif discount.code.upcase != discount_code.upcase
      errors.add(:discount_code, 'does not match the selected discount')
    end
  end
end
