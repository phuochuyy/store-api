# == Schema Information
#
# Table name: categories
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  description :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Category < ApplicationRecord
  has_many :products, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { minimum: 2, maximum: 50 }
  validates :description, presence: true, length: { minimum: 10, maximum: 500 }

  # Scope for categories with products
  scope :with_products, -> { joins(:products).distinct }
end
