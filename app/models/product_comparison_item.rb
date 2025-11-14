# == Schema Information
#
# Table name: product_comparison_items
#
#  id                    :integer          not null, primary key
#  product_comparison_id :integer          not null
#  product_id            :integer          not null
#  position              :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#

class ProductComparisonItem < ApplicationRecord
  belongs_to :product_comparison
  belongs_to :product

  validates :product_comparison_id, uniqueness: { scope: :product_id, message: 'Product already in this comparison' }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :ordered, -> { order(:position, :created_at) }
end

