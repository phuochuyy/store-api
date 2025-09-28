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
  has_many :cart_items, dependent: :destroy
  has_many :carts, through: :cart_items
  has_many :stock_alerts, dependent: :destroy

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

  # Scope for products with stock alerts
  scope :with_alerts, -> { joins(:stock_alerts).where(stock_alerts: { status: 'active' }) }

  # Scope for low stock products
  scope :low_stock, -> { where('stock_quantity <= 10') }

  # Scope for out of stock products
  scope :out_of_stock, -> { where(stock_quantity: 0) }

  # Callbacks
  after_update :check_stock_alerts, if: :saved_change_to_stock_quantity?

  def in_stock?
    stock_quantity.positive?
  end

  def reduce_stock(quantity)
    self.stock_quantity -= quantity
    save!
  end

  def add_stock(quantity)
    self.stock_quantity += quantity
    save!
  end

  # Stock alert methods
  def current_stock_alert
    stock_alerts.active_alerts.first
  end

  def has_active_alert?
    stock_alerts.active_alerts.exists?
  end

  def stock_status
    case stock_quantity
    when 0
      'out_of_stock'
    when 1..5
      'critical'
    when 6..10
      'low'
    when 11..20
      'reorder_point'
    else
      'sufficient'
    end
  end

  def stock_status_color
    case stock_status
    when 'out_of_stock'
      'red'
    when 'critical'
      'orange'
    when 'low'
      'yellow'
    when 'reorder_point'
      'blue'
    else
      'green'
    end
  end

  def stock_status_message
    case stock_status
    when 'out_of_stock'
      'Out of stock'
    when 'critical'
      'Critical stock level'
    when 'low'
      'Low stock level'
    when 'reorder_point'
      'Reorder point reached'
    else
      'Stock sufficient'
    end
  end

  def check_stock_alerts
    # Resolve existing alerts if stock has improved
    StockAlert.resolve_alerts_for_product(self)

    # Create new alerts if stock has decreased
    StockAlert.check_and_create_alerts_for_product(self)
  end

  def trigger_stock_alert(alert_type, threshold = nil)
    StockAlert.create_alert_for_product(self, alert_type, threshold)
  end
end
