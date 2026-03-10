class Discount < ApplicationRecord
  # Associations
  has_many :coupons, dependent: :destroy
  has_many :orders, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :discount_type, presence: true, inclusion: { in: %w[percentage fixed_amount free_shipping] }
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :minimum_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :maximum_discount, numericality: { greater_than: 0 }, allow_nil: true
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validates :applies_to, inclusion: { in: %w[all products categories brands] }

  scope :active, -> { where(is_active: true) }
  scope :current, lambda {
    where('start_date IS NULL OR start_date <= ?', Time.current)
      .where('end_date IS NULL OR end_date >= ?', Time.current)
  }
  scope :available, -> { active.current }
  scope :percentage, -> { where(discount_type: 'percentage') }
  scope :fixed_amount, -> { where(discount_type: 'fixed_amount') }
  scope :free_shipping, -> { where(discount_type: 'free_shipping') }

  before_validation :generate_code, on: :create
  before_validation :normalize_code
  validate :valid_discount_value
  validate :valid_date_range

  # Instance methods
  def available?
    is_active? && current? && within_usage_limit?
  end

  def current?
    (start_date.nil? || start_date <= Time.current) &&
      (end_date.nil? || end_date >= Time.current)
  end

  def within_usage_limit?
    usage_limit.nil? || used_count < usage_limit
  end

  def expired?
    end_date.present? && end_date < Time.current
  end

  def calculate_discount(amount)
    return 0 unless available?

    case discount_type
    when 'percentage'
      discount = (amount * value / 100.0).round(2)
      maximum_discount.present? ? [discount, maximum_discount].min : discount
    when 'fixed_amount'
      [value, amount].min
    when 'free_shipping'
      0 # Free shipping is handled separately
    end
  end

  def applies_to_items?(items)
    return true if applies_to == 'all'

    case applies_to
    when 'products'
      product_ids = items.map(&:product_id)
      applies_to_ids.split(',').map(&:to_i).any? { |id| product_ids.include?(id) }
    when 'categories'
      category_ids = items.map { |item| item.product.category_id }
      applies_to_ids.split(',').map(&:to_i).any? { |id| category_ids.include?(id) }
    when 'brands'
      brand_ids = items.map { |item| item.product.brand_id }
      applies_to_ids.split(',').map(&:to_i).any? { |id| brand_ids.include?(id) }
    else
      false
    end
  end

  def meets_minimum_amount?(amount)
    minimum_amount.nil? || amount >= minimum_amount
  end

  def increment_usage!
    update!(used_count: used_count + 1)
  end

  def decrement_usage!
    update!(used_count: used_count - 1) if used_count.positive?
  end

  private

  def generate_code
    self.code ||= generate_unique_code
  end

  def generate_unique_code
    loop do
      code = "DISC#{SecureRandom.hex(4).upcase}"
      break code unless Discount.exists?(code: code)
    end
  end

  def normalize_code
    self.code = code&.upcase&.strip
  end

  def valid_discount_value
    case discount_type
    when 'percentage'
      errors.add(:value, 'must be between 0 and 100 for percentage discounts') if value > 100
    when 'fixed_amount'
      errors.add(:value, 'must be positive for fixed amount discounts') if value <= 0
    end
  end

  def valid_date_range
    return unless start_date.present? && end_date.present?

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end
end
