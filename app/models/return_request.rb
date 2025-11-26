# frozen_string_literal: true

# == Schema Information
#
# Table name: return_requests
#
#  id              :integer          not null, primary key
#  order_id        :integer          not null
#  user_id         :integer          not null
#  status          :string           default("pending"), not null
#  reason          :text
#  requested_at    :datetime
#  processed_at    :datetime
#  refund_amount   :decimal(10, 2)   default(0.0)
#  return_type     :string           default("refund")
#  admin_notes     :text
#  approved_at     :datetime
#  rejected_at     :datetime
#  rejection_reason :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class ReturnRequest < ApplicationRecord
  belongs_to :order
  belongs_to :user
  has_many :return_items, dependent: :destroy
  has_many :order_items, through: :return_items

  validates :status, presence: true, inclusion: {
    in: %w[pending approved rejected processing completed cancelled]
  }
  validates :return_type, inclusion: { in: %w[refund exchange] }
  validates :reason, presence: true, length: { minimum: 10, maximum: 1000 }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }

  enum :status, {
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected',
    processing: 'processing',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  before_create :set_requested_at

  def can_be_approved?
    pending?
  end

  def can_be_rejected?
    pending?
  end

  def can_be_cancelled?
    %w[pending approved].include?(status)
  end

  def total_quantity
    return_items.sum(:quantity)
  end

  def calculate_refund_amount
    return_items.sum(:refund_amount) || 0.0
  end

  def approve!(admin_notes: nil)
    return false unless can_be_approved?

    update!(
      status: 'approved',
      approved_at: Time.current,
      admin_notes: admin_notes
    )
    true
  end

  def reject!(rejection_reason)
    return false unless can_be_rejected?

    update!(
      status: 'rejected',
      rejected_at: Time.current,
      rejection_reason: rejection_reason
    )
    true
  end

  def cancel!
    return false unless can_be_cancelled?

    update!(status: 'cancelled')
    true
  end

  def complete!
    return false unless processing?

    update!(
      status: 'completed',
      processed_at: Time.current
    )
    true
  end

  private

  def set_requested_at
    self.requested_at ||= Time.current
  end
end

