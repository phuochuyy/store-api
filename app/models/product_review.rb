class ProductReview < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :product_id }

  scope :approved, -> { where(status: 'approved') }
  scope :recent, -> { order(created_at: :desc) }
  scope :verified_purchases, -> { where(verified_purchase: true) }
  scope :most_helpful, -> { order(helpful_count: :desc) }
end

