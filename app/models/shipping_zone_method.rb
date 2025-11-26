# frozen_string_literal: true

# == Schema Information
#
# Table name: shipping_zone_methods
#
#  id                :integer          not null, primary key
#  shipping_zone_id  :integer          not null
#  shipping_method_id :integer          not null
#  cost_multiplier   :decimal(5, 2)    default(1.0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class ShippingZoneMethod < ApplicationRecord
  belongs_to :shipping_zone
  belongs_to :shipping_method

  validates :cost_multiplier, presence: true, numericality: { greater_than: 0 }
  validates :shipping_zone_id, uniqueness: { scope: :shipping_method_id }
end
