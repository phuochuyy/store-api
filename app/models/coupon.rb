class Coupon < ApplicationRecord
  # Associations
  belongs_to :discount
  belongs_to :user, optional: true
  belongs_to :order, optional: true

  # Validations
  validates :code, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active used expired cancelled] }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: 'active') }
  scope :used, -> { where(status: 'used') }
  scope :expired, -> { where(status: 'expired') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :available, -> { active.where(used_at: nil) }

  before_validation :generate_code, on: :create
  before_validation :normalize_code
  before_save :set_used_at_if_used

  # Instance methods
  def available?
    active? && !used? && !expired? && discount.available?
  end

  def used?
    status == 'used' || used_at.present?
  end

  def expired?
    status == 'expired' || discount.expired?
  end

  def use!(order, user = nil)
    return { success: false, error: 'Coupon not available' } unless available?

    ActiveRecord::Base.transaction do
      self.order = order
      self.user = user if user.present?
      self.status = 'used'
      self.used_at = Time.current
      self.discount_amount = discount.calculate_discount(order.total_amount)
      save!

      discount.increment_usage!
    end

    { success: true, discount_amount: discount_amount }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def cancel!
    return { success: false, error: 'Cannot cancel used coupon' } if used?

    update!(status: 'cancelled')
    { success: true }
  end

  def expire!
    update!(status: 'expired')
  end

  private

  def generate_code
    self.code ||= generate_unique_code
  end

  def generate_unique_code
    loop do
      code = "COUPON#{SecureRandom.hex(6).upcase}"
      break code unless Coupon.exists?(code: code)
    end
  end

  def normalize_code
    self.code = code&.upcase&.strip
  end

  def set_used_at_if_used
    self.used_at = Time.current if status == 'used' && used_at.nil?
  end
end
