# == Schema Information
#
# Table name: products
#
#  id             :integer          not null, primary key
#  name           :string(255)
#  description    :text(65535)
#  price          :decimal(10, 2)
#  brand_id       :integer          not null
#  category_id    :integer          not null
#  stock_quantity :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_products_on_brand_id     (brand_id)
#  index_products_on_category_id  (category_id)
#

class Product < ApplicationRecord
  belongs_to :brand
  belongs_to :category
  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  # Active Storage for image uploads
  has_one_attached :image

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :price, presence: true, numericality: { greater_than: 0, less_than: 100_000 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 10_000 }

  # Scope for available products (in stock)
  scope :available, -> { where('stock_quantity > 0') }

  # Scope for expensive products (price > 1000)
  scope :expensive, -> { where('price > 1000') }

  def in_stock?
    stock_quantity.positive?
  end

  def reduce_stock(quantity)
    self.stock_quantity -= quantity
    save!
  end
end
