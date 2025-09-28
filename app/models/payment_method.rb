# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_methods
#
#  id                        :integer          not null, primary key
#  name                      :string           not null
#  description               :text
#  is_active                 :boolean          default(TRUE), not null
#  gateway_type              :string
#  gateway_config            :json
#  processing_fee_percentage :decimal(5, 2)    default(0.0)
#  processing_fee_fixed      :decimal(10, 2)   default(0.0)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class PaymentMethod < ApplicationRecord
  # Associations
  has_many :payments, dependent: :restrict_with_exception

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :gateway_type, presence: true
  validates :processing_fee_percentage,
            presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :processing_fee_fixed,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  # Enums
  enum :gateway_type, {
    stripe: 'stripe',
    paypal: 'paypal',
    bank_transfer: 'bank_transfer',
    cash_on_delivery: 'cash_on_delivery',
    wallet: 'wallet'
  }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_gateway_type, ->(type) { where(gateway_type: type) }

  # Callbacks
  before_validation :set_defaults

  # Methods
  def calculate_processing_fee(amount)
    return 0 if amount.blank? || amount <= 0

    percentage_fee = (amount * processing_fee_percentage / 100).round(2)
    total_fee = percentage_fee + processing_fee_fixed

    total_fee.round(2)
  end

  def total_amount_with_fees(amount)
    return amount if amount.blank? || amount <= 0

    amount + calculate_processing_fee(amount)
  end

  def gateway_configured?
    gateway_config.present? && gateway_config.is_a?(Hash)
  end

  def supports_refunds?
    %w[stripe paypal].include?(gateway_type)
  end

  def supports_partial_refunds?
    %w[stripe].include?(gateway_type)
  end

  private

  def set_defaults
    self.processing_fee_percentage ||= 0.0
    self.processing_fee_fixed ||= 0.0
  end
end
