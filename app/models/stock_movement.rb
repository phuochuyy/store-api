class StockMovement < ApplicationRecord
  belongs_to :product
  belongs_to :user, optional: true

  validates :movement_type, presence: true
  validates :quantity, presence: true, numericality: { other_than: 0 }
  validates :previous_quantity, presence: true
  validates :new_quantity, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_movement_type, ->(type) { where(movement_type: type) }

  def self.get_movements_for_product(product, options = {})
    movements = where(product: product)
    movements = movements.by_movement_type(options[:movement_type]) if options[:movement_type]
    movements = movements.recent.limit(options[:limit]) if options[:limit]
    movements
  end

  def self.get_movement_summary(product, start_date = nil, end_date = nil)
    movements = where(product: product)
    movements = movements.where('created_at >= ?', start_date) if start_date
    movements = movements.where('created_at <= ?', end_date) if end_date
    movements
  end
end

