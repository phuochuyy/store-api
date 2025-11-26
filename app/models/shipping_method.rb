# frozen_string_literal: true

# == Schema Information
#
# Table name: shipping_methods
#
#  id             :integer          not null, primary key
#  name           :string           not null
#  description    :text
#  base_cost      :decimal(10, 2)   default(0.0), not null
#  handling_fee   :decimal(10, 2)   default(0.0), not null
#  is_active      :boolean          default(TRUE), not null
#  estimated_days :integer          default(3), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class ShippingMethod < ApplicationRecord
  has_many :shipping_zone_methods, dependent: :destroy
  has_many :shipping_zones, through: :shipping_zone_methods
  has_many :orders, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :base_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :handling_fee, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :estimated_days, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(is_active: true) }

  def total_base_cost
    base_cost + handling_fee
  end
end
