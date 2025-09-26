class PhoneValidator
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :description, :string
  attribute :price, :decimal
  attribute :stock_quantity, :integer
  attribute :brand_id, :integer
  attribute :category_id, :integer
  attribute :specifications, :string

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :brand_id, presence: true
  validates :category_id, presence: true

  validate :brand_exists
  validate :category_exists
  validate :valid_specifications

  private

  def brand_exists
    return if brand_id.blank?

    return if Brand.exists?(brand_id)

    errors.add(:brand_id, 'Brand does not exist')
  end

  def category_exists
    return if category_id.blank?

    return if Category.exists?(category_id)

    errors.add(:category_id, 'Category does not exist')
  end

  def valid_specifications
    return if specifications.blank?

    begin
      JSON.parse(specifications) if specifications.is_a?(String)
    rescue JSON::ParserError
      errors.add(:specifications, 'Invalid JSON format')
    end
  end
end
