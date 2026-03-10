class Promotion < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :promotion_type, presence: true, inclusion: {
    in: %w[bulk_pricing buy_x_get_y free_gift shipping_discount]
  }
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validates :priority, inclusion: { in: %w[high normal low] }

  scope :active, -> { where(is_active: true) }
  scope :current, lambda {
    where('start_date IS NULL OR start_date <= ?', Time.current)
      .where('end_date IS NULL OR end_date >= ?', Time.current)
  }
  scope :available, -> { active.current }
  scope :stackable, -> { where(stackable: true) }
  scope :high_priority, -> { where(priority: 'high') }
  scope :normal_priority, -> { where(priority: 'normal') }
  scope :low_priority, -> { where(priority: 'low') }

  validate :valid_date_range
  validate :valid_conditions_and_benefits

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

  def applies_to_order?(order)
    return false unless available?
    return false unless meets_conditions?(order)

    case promotion_type
    when 'bulk_pricing'
      applies_bulk_pricing?(order)
    when 'buy_x_get_y'
      applies_buy_x_get_y?(order)
    when 'free_gift'
      applies_free_gift?(order)
    when 'shipping_discount'
      applies_shipping_discount?(order)
    else
      false
    end
  end

  def calculate_benefit(order)
    return { discount_amount: 0, free_items: [], free_shipping: false } unless applies_to_order?(order)

    case promotion_type
    when 'bulk_pricing'
      { discount_amount: calculate_bulk_discount(order), free_items: [], free_shipping: false }
    when 'buy_x_get_y'
      { discount_amount: 0, free_items: calculate_free_items(order), free_shipping: false }
    when 'free_gift'
      { discount_amount: 0, free_items: calculate_gift_items(order), free_shipping: false }
    when 'shipping_discount'
      { discount_amount: 0, free_items: [], free_shipping: true }
    else
      { discount_amount: 0, free_items: [], free_shipping: false }
    end
  end

  def increment_usage!
    update!(used_count: used_count + 1)
  end

  private

  def valid_date_range
    return unless start_date.present? && end_date.present?

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def valid_conditions_and_benefits
    errors.add(:conditions, 'must be valid JSON') unless valid_json?(conditions)
    errors.add(:benefits, 'must be valid JSON') unless valid_json?(benefits)
  end

  def valid_json?(json_data)
    return true if json_data.nil?

    JSON.parse(json_data.to_json)
    true
  rescue JSON::ParserError
    false
  end

  def meets_conditions?(order)
    return true if conditions.blank?

    conditions_data = conditions.is_a?(String) ? JSON.parse(conditions) : conditions

    # Check minimum order amount
    if conditions_data['minimum_amount'].present? && (order.total_amount < conditions_data['minimum_amount'])
      return false
    end

    # Check specific products
    if conditions_data['product_ids'].present?
      order_product_ids = order.order_items.map(&:product_id)
      return false unless conditions_data['product_ids'].any? { |id| order_product_ids.include?(id) }
    end

    # Check specific categories
    if conditions_data['category_ids'].present?
      order_category_ids = order.order_items.map { |item| item.product.category_id }
      return false unless conditions_data['category_ids'].any? { |id| order_category_ids.include?(id) }
    end

    # Check specific brands
    if conditions_data['brand_ids'].present?
      order_brand_ids = order.order_items.map { |item| item.product.brand_id }
      return false unless conditions_data['brand_ids'].any? { |id| order_brand_ids.include?(id) }
    end

    true
  end

  def applies_bulk_pricing?(order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    return false if benefits_data['tiers'].blank?

    total_quantity = order.order_items.sum(&:quantity)
    benefits_data['tiers'].any? { |tier| total_quantity >= tier['min_quantity'] }
  end

  def applies_buy_x_get_y?(order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    return false unless benefits_data['buy_quantity'].present? && benefits_data['get_quantity'].present?

    applicable_items = get_applicable_items(order)
    applicable_items.any? { |item| item.quantity >= benefits_data['buy_quantity'] }
  end

  def applies_free_gift?(_order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    benefits_data['gift_product_id'].present?
  end

  def applies_shipping_discount?(_order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    benefits_data['free_shipping'] == true
  end

  def calculate_bulk_discount(order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    return 0 if benefits_data['tiers'].blank?

    total_quantity = order.order_items.sum(&:quantity)
    applicable_tier = benefits_data['tiers']
                      .select { |tier| total_quantity >= tier['min_quantity'] }
                      .max_by { |tier| tier['min_quantity'] }

    return 0 unless applicable_tier

    if applicable_tier['discount_type'] == 'percentage'
      (order.total_amount * applicable_tier['discount_value'] / 100.0).round(2)
    else
      applicable_tier['discount_value']
    end
  end

  def calculate_free_items(order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    return [] unless benefits_data['buy_quantity'].present? && benefits_data['get_quantity'].present?

    free_items = []
    applicable_items = get_applicable_items(order)

    applicable_items.each do |item|
      free_quantity = (item.quantity / benefits_data['buy_quantity']) * benefits_data['get_quantity']
      next unless free_quantity.positive?

      free_items << {
        product_id: item.product_id,
        quantity: free_quantity,
        product: item.product
      }
    end

    free_items
  end

  def calculate_gift_items(_order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits
    return [] if benefits_data['gift_product_id'].blank?

    gift_product = Product.find_by(id: benefits_data['gift_product_id'])
    return [] unless gift_product

    [{
      product_id: gift_product.id,
      quantity: benefits_data['gift_quantity'] || 1,
      product: gift_product
    }]
  end

  def get_applicable_items(order)
    benefits_data = benefits.is_a?(String) ? JSON.parse(benefits) : benefits

    if benefits_data['product_ids'].present?
      order.order_items.joins(:product).where(products: { id: benefits_data['product_ids'] })
    elsif benefits_data['category_ids'].present?
      order.order_items.joins(:product).where(products: { category_id: benefits_data['category_ids'] })
    elsif benefits_data['brand_ids'].present?
      order.order_items.joins(:product).where(products: { brand_id: benefits_data['brand_ids'] })
    else
      order.order_items
    end
  end
end
