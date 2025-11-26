# frozen_string_literal: true

# == Schema Information
#
# Table name: variant_options
#
#  id                :integer          not null, primary key
#  product_variant_id :integer          not null
#  option_type       :string           not null
#  option_value      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class VariantOption < ApplicationRecord
  belongs_to :product_variant

  validates :option_type, presence: true
  validates :option_value, presence: true

  # Common option types: size, color, material, etc.
  OPTION_TYPES = %w[size color material style].freeze

  scope :by_type, ->(type) { where(option_type: type) }
end

