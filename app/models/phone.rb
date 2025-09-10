class Phone < ApplicationRecord
  belongs_to :brand
  belongs_to :category
  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :description, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :image_url, presence: true
  validates :specifications, presence: true
end
