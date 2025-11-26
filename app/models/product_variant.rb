# frozen_string_literal: true

# == Schema Information
#
# Table name: product_variants
#
#  id             :integer          not null, primary key
#  product_id     :integer          not null
#  name           :string           not null
#  sku            :string           not null
#  price          :decimal(10, 2)   not null
#  stock_quantity :integer          default(0), not null
#  is_active      :boolean          default(TRUE), not null
#  position       :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class ProductVariant < ApplicationRecord
  belongs_to :product
  has_many :variant_options, dependent: :destroy
  has_many :order_items, dependent: :nullify
  has_many :cart_items, dependent: :nullify

  accepts_nested_attributes_for :variant_options, allow_destroy: true

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :in_stock, -> { where('stock_quantity > 0') }
  scope :ordered, -> { order(:position, :name) }

  def in_stock?
    stock_quantity.positive?
  end

  def out_of_stock?
    stock_quantity.zero?
  end

  def low_stock?(threshold = 10)
    stock_quantity <= threshold
  end

  def variant_display_name
    options = variant_options.order(:option_type).map(&:option_value)
    options.any? ? "#{product.name} - #{options.join(', ')}" : name
  end

  def reduce_stock(quantity, reason: nil)
    return false if quantity <= 0
    return false if stock_quantity < quantity

    update!(stock_quantity: stock_quantity - quantity)
    true
  end

  def add_stock(quantity, reason: nil)
    return false if quantity <= 0

    update!(stock_quantity: stock_quantity + quantity)
    true
  end
end

