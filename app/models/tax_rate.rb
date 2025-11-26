# frozen_string_literal: true

# == Schema Information
#
# Table name: tax_rates
#
#  id           :integer          not null, primary key
#  name         :string           not null
#  country_code :string           not null
#  region       :string
#  category_id  :integer
#  tax_rate     :decimal(5, 2)     not null
#  tax_type     :string           default("VAT"), not null
#  is_active    :boolean          default(TRUE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class TaxRate < ApplicationRecord
  belongs_to :category, optional: true
  has_many :orders, dependent: :nullify

  validates :name, presence: true
  validates :country_code, presence: true
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :tax_type, presence: true, inclusion: { in: %w[VAT GST Sales] }

  scope :active, -> { where(is_active: true) }
  scope :for_country, ->(country_code) { where(country_code: country_code) }
  scope :for_region, ->(country_code, region) { where(country_code: country_code, region: region) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :general, -> { where(category_id: nil) }

  def matches?(country_code, region = nil, category_id = nil)
    return false unless self.country_code == country_code
    return false if region.present? && self.region.present? && self.region != region
    return false if category_id.present? && self.category_id.present? && self.category_id != category_id

    true
  end

  def calculate_tax(amount)
    (amount * tax_rate / 100.0).round(2)
  end
end
