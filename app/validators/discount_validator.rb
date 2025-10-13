class DiscountValidator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :name, :string
  attribute :description, :string
  attribute :discount_type, :string
  attribute :value, :decimal
  attribute :minimum_amount, :decimal
  attribute :maximum_discount, :decimal
  attribute :usage_limit, :integer
  attribute :start_date, :datetime
  attribute :end_date, :datetime
  attribute :is_active, :boolean
  attribute :code, :string
  attribute :applies_to, :string
  attribute :applies_to_ids, :string
  attribute :conditions, :string

  validates :name, presence: true, length: { maximum: 255 }
  validates :discount_type, presence: true, inclusion: { in: %w[percentage fixed_amount free_shipping] }
  validates :value, presence: true, numericality: { greater_than: 0 }
  validates :minimum_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :maximum_discount, numericality: { greater_than: 0 }, allow_nil: true
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :applies_to, inclusion: { in: %w[all products categories brands] }
  validates :code, presence: true, length: { minimum: 3, maximum: 50 }
  validates :code,
            format: { with: /\A[A-Z0-9_]+\z/, message: I18n.t('validators.discount.code_format_message') }

  validate :valid_discount_value
  validate :valid_date_range
  validate :valid_conditions_json
  validate :valid_applies_to_ids

  private

  def valid_discount_value
    case discount_type
    when 'percentage'
      errors.add(:value, 'must be between 0 and 100 for percentage discounts') if value > 100
    when 'fixed_amount'
      errors.add(:value, 'must be positive for fixed amount discounts') if value <= 0
    when 'free_shipping'
      # Free shipping doesn't need a value
    end
  end

  def valid_date_range
    return unless start_date.present? && end_date.present?

    return unless end_date <= start_date

    errors.add(:end_date, 'must be after start date')
  end

  def valid_conditions_json
    return if conditions.blank?

    begin
      JSON.parse(conditions)
    rescue JSON::ParserError
      errors.add(:conditions, 'must be valid JSON')
    end
  end

  def valid_applies_to_ids
    return if applies_to == 'all' || applies_to_ids.blank?

    # Check if applies_to_ids contains valid comma-separated integers
    ids = applies_to_ids.split(',').map(&:strip)

    ids.each do |id|
      unless id.match?(/\A\d+\z/)
        errors.add(:applies_to_ids, 'must contain only comma-separated integers')
        break
      end
    end

    # Validate that the referenced IDs exist
    case applies_to
    when 'products'
      validate_ids_exist(Product, ids, 'products')
    when 'categories'
      validate_ids_exist(Category, ids, 'categories')
    when 'brands'
      validate_ids_exist(Brand, ids, 'brands')
    end
  end

  def validate_ids_exist(model_class, ids, type_name)
    existing_ids = model_class.where(id: ids).pluck(:id).map(&:to_s)
    missing_ids = ids - existing_ids

    return unless missing_ids.any?

    errors.add(:applies_to_ids, "references non-existent #{type_name}: #{missing_ids.join(', ')}")
  end
end
