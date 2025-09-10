class Brand < ApplicationRecord
  has_many :phones, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
end
