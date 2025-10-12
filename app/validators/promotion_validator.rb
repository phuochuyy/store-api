class PromotionValidator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :name, :string
  attribute :description, :string
  attribute :promotion_type, :string
  attribute :conditions, :string
  attribute :benefits, :string
  attribute :start_date, :datetime
  attribute :end_date, :datetime
  attribute :is_active, :boolean
  attribute :usage_limit, :integer
  attribute :priority, :string
  attribute :stackable, :boolean

  validates :name, presence: true, length: { maximum: 255 }
  validates :promotion_type, presence: true, inclusion: { 
    in: %w[bulk_pricing buy_x_get_y free_gift shipping_discount] 
  }
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :priority, inclusion: { in: %w[high normal low] }
  validates :stackable, inclusion: { in: [true, false] }

  validate :valid_date_range
  validate :valid_conditions_json
  validate :valid_benefits_json
  validate :valid_promotion_structure

  private

  def valid_date_range
    return unless start_date.present? && end_date.present?

    if end_date <= start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def valid_conditions_json
    return if conditions.blank?

    begin
      parsed_conditions = JSON.parse(conditions)
      validate_conditions_structure(parsed_conditions)
    rescue JSON::ParserError
      errors.add(:conditions, 'must be valid JSON')
    end
  end

  def valid_benefits_json
    return if benefits.blank?

    begin
      parsed_benefits = JSON.parse(benefits)
      validate_benefits_structure(parsed_benefits)
    rescue JSON::ParserError
      errors.add(:benefits, 'must be valid JSON')
    end
  end

  def valid_promotion_structure
    return if promotion_type.blank?

    case promotion_type
    when 'bulk_pricing'
      validate_bulk_pricing_structure
    when 'buy_x_get_y'
      validate_buy_x_get_y_structure
    when 'free_gift'
      validate_free_gift_structure
    when 'shipping_discount'
      validate_shipping_discount_structure
    end
  end

  def validate_conditions_structure(conditions)
    # Validate common condition fields
    if conditions['minimum_amount'].present?
      unless conditions['minimum_amount'].is_a?(Numeric) && conditions['minimum_amount'] > 0
        errors.add(:conditions, 'minimum_amount must be a positive number')
      end
    end

    if conditions['product_ids'].present?
      unless conditions['product_ids'].is_a?(Array) && conditions['product_ids'].all? { |id| id.is_a?(Integer) }
        errors.add(:conditions, 'product_ids must be an array of integers')
      end
    end

    if conditions['category_ids'].present?
      unless conditions['category_ids'].is_a?(Array) && conditions['category_ids'].all? { |id| id.is_a?(Integer) }
        errors.add(:conditions, 'category_ids must be an array of integers')
      end
    end

    if conditions['brand_ids'].present?
      unless conditions['brand_ids'].is_a?(Array) && conditions['brand_ids'].all? { |id| id.is_a?(Integer) }
        errors.add(:conditions, 'brand_ids must be an array of integers')
      end
    end
  end

  def validate_benefits_structure(benefits)
    # This will be validated based on promotion_type in valid_promotion_structure
  end

  def validate_bulk_pricing_structure
    return if benefits.blank?

    begin
      parsed_benefits = JSON.parse(benefits)
      
      unless parsed_benefits['tiers'].is_a?(Array) && parsed_benefits['tiers'].any?
        errors.add(:benefits, 'bulk_pricing requires tiers array')
        return
      end

      parsed_benefits['tiers'].each_with_index do |tier, index|
        unless tier.is_a?(Hash)
          errors.add(:benefits, "tier #{index} must be an object")
          next
        end

        unless tier['min_quantity'].is_a?(Integer) && tier['min_quantity'] > 0
          errors.add(:benefits, "tier #{index} min_quantity must be a positive integer")
        end

        unless tier['discount_type'].in?(%w[percentage fixed_amount])
          errors.add(:benefits, "tier #{index} discount_type must be 'percentage' or 'fixed_amount'")
        end

        unless tier['discount_value'].is_a?(Numeric) && tier['discount_value'] > 0
          errors.add(:benefits, "tier #{index} discount_value must be a positive number")
        end

        if tier['discount_type'] == 'percentage' && tier['discount_value'] > 100
          errors.add(:benefits, "tier #{index} percentage discount cannot exceed 100%")
        end
      end
    rescue JSON::ParserError
      errors.add(:benefits, 'must be valid JSON for bulk_pricing')
    end
  end

  def validate_buy_x_get_y_structure
    return if benefits.blank?

    begin
      parsed_benefits = JSON.parse(benefits)
      
      unless parsed_benefits['buy_quantity'].is_a?(Integer) && parsed_benefits['buy_quantity'] > 0
        errors.add(:benefits, 'buy_quantity must be a positive integer')
      end

      unless parsed_benefits['get_quantity'].is_a?(Integer) && parsed_benefits['get_quantity'] > 0
        errors.add(:benefits, 'get_quantity must be a positive integer')
      end
    rescue JSON::ParserError
      errors.add(:benefits, 'must be valid JSON for buy_x_get_y')
    end
  end

  def validate_free_gift_structure
    return if benefits.blank?

    begin
      parsed_benefits = JSON.parse(benefits)
      
      unless parsed_benefits['gift_product_id'].is_a?(Integer) && parsed_benefits['gift_product_id'] > 0
        errors.add(:benefits, 'gift_product_id must be a positive integer')
      end

      if parsed_benefits['gift_quantity'].present?
        unless parsed_benefits['gift_quantity'].is_a?(Integer) && parsed_benefits['gift_quantity'] > 0
          errors.add(:benefits, 'gift_quantity must be a positive integer')
        end
      end
    rescue JSON::ParserError
      errors.add(:benefits, 'must be valid JSON for free_gift')
    end
  end

  def validate_shipping_discount_structure
    return if benefits.blank?

    begin
      parsed_benefits = JSON.parse(benefits)
      
      unless parsed_benefits['free_shipping'] == true
        errors.add(:benefits, 'shipping_discount requires free_shipping: true')
      end
    rescue JSON::ParserError
      errors.add(:benefits, 'must be valid JSON for shipping_discount')
    end
  end
end
