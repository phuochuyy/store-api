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

  def reduce_stock(quantity, reason: nil, user: nil, reference: nil)
    return false if quantity <= 0
    return false if stock_quantity < quantity

    StockTracking::StockTrackingService.track_stock_movement(
      product: self,
      movement_type: 'order_created',
      quantity: -quantity,
      reason: reason,
      user: user,
      reference: reference
    )
  end

  def add_stock(quantity, reason: nil, user: nil, reference: nil)
    return false if quantity <= 0

    StockTracking::StockTrackingService.track_stock_movement(
      product: self,
      movement_type: 'order_cancelled',
      quantity: quantity,
      reason: reason,
      user: user,
      reference: reference
    )
  end

  # Stock alert methods
  def current_stock_alert
    stock_alerts.active_alerts.first
  end

  def active_alert?
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

  # Stock tracking methods
  def stock_movement_history(options = {})
    StockMovement.get_movements_for_product(self, options)
  end

  def stock_movement_summary(start_date = nil, end_date = nil)
    StockMovement.get_movement_summary(self, start_date, end_date)
  end

  def recent_stock_movements(limit = 10)
    stock_movements.recent.limit(limit)
  end

  def stock_movements_by_type(movement_type)
    stock_movements.by_movement_type(movement_type)
  end

  # Review and rating methods
  def approved_reviews
    product_reviews.approved
  end

  def average_rating
    @average_rating ||= approved_reviews.average(:rating)&.round(1) || 0
  end

  def total_reviews
    @total_reviews ||= approved_reviews.count
  end

  def rating_distribution
    @rating_distribution ||= approved_reviews.group(:rating).count.transform_keys(&:to_i)
  end

  def verified_reviews
    approved_reviews.verified_purchases
  end

  def recent_reviews(limit = 5)
    approved_reviews.recent.limit(limit)
  end

  def most_helpful_reviews(limit = 5)
    approved_reviews.most_helpful.limit(limit)
  end

  def update_rating_stats
    # This method can be called to refresh cached rating statistics
    @average_rating = nil
    @total_reviews = nil
    @rating_distribution = nil
  end

  # Wishlist methods
  def wishlist_count
    product_wishlists.count
  end

  def in_user_wishlist?(user)
    return false unless user

    product_wishlists.exists?(user: user)
  end

  def add_to_wishlist(user, notes: nil, priority: 0)
    return false unless user
    return false if in_user_wishlist?(user)

    product_wishlists.create!(user: user, notes: notes, priority: priority)
  end

  def remove_from_wishlist(user)
    return false unless user

    wishlist_item = product_wishlists.find_by(user: user)
    wishlist_item&.destroy
  end

  # Recommendation methods
  def similar_products(limit = 5)
    Product.joins(:category, :brand)
           .where(category: category)
           .where.not(id: id)
           .where.not(brand: brand)
           .limit(limit)
  end

  def products_from_same_brand(limit = 5)
    Product.joins(:brand)
           .where(brand: brand)
           .where.not(id: id)
           .limit(limit)
  end

  def products_from_same_category(limit = 5)
    Product.joins(:category)
           .where(category: category)
           .where.not(id: id)
           .limit(limit)
  end

  def recommended_products(limit = 5)
    # Simple recommendation based on category and brand
    similar_products(limit)
  end
end
