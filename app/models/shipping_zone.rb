# frozen_string_literal: true

# == Schema Information
#
# Table name: shipping_zones
#
#  id                      :integer          not null, primary key
#  name                    :string           not null
#  country_code             :string           not null
#  region                   :string
#  base_cost                :decimal(10, 2)   default(0.0), not null
#  cost_per_kg              :decimal(10, 2)   default(0.0), not null
#  free_shipping_threshold  :decimal(10, 2)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
class ShippingZone < ApplicationRecord
  has_many :shipping_zone_methods, dependent: :destroy
  has_many :shipping_methods, through: :shipping_zone_methods

  validates :name, presence: true
  validates :country_code, presence: true
  validates :base_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_per_kg, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :for_country, ->(country_code) { where(country_code: country_code) }
  scope :for_region, ->(country_code, region) { where(country_code: country_code, region: region) }

  def matches?(country_code, region = nil)
    return false unless self.country_code == country_code
    return true if region.blank? || self.region.blank?

    self.region == region
  end
end
