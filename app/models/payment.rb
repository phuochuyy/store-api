# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id               :integer          not null, primary key
#  order_id         :integer          not null
#  payment_method_id :integer          not null
#  amount           :decimal(10, 2)   not null
#  status           :string           default("pending"), not null
#  transaction_id   :string
#  gateway_response :text
#  processed_at     :datetime
#  failure_reason   :string
#  metadata         :json
#  currency         :string           default("USD"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Payment < ApplicationRecord
  # Associations
  belongs_to :order
  belongs_to :payment_method
  # PaymentHistory model may not exist, so we make this conditional
  if defined?(PaymentHistory)
    has_many :payment_histories, dependent: :destroy
  end

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :currency, presence: true
  validates :transaction_id, uniqueness: true, allow_nil: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled',
    refunded: 'refunded',
    partially_refunded: 'partially_refunded'
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'completed') }
  scope :failed, -> { where(status: %w[failed cancelled]) }
  scope :refundable, -> { successful }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_payment_method, ->(method) { where(payment_method: method) }

  before_validation :set_defaults
  after_create :track_creation
  after_update :update_order_status, if: :saved_change_to_status?
  after_update :track_changes

  # Methods
  def processing_fee
    payment_method.calculate_processing_fee(amount)
  end

  def total_amount
    amount + processing_fee
  end

  def successful?
    completed?
  end

  def failed?
    %w[failed cancelled].include?(status)
  end

  def refundable?
    completed? && payment_method.supports_refunds?
  end

  def partially_refundable?
    completed? && payment_method.supports_partial_refunds?
  end

  def can_be_refunded?
    refundable? || partially_refundable?
  end

  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_completed!(transaction_id: nil, gateway_response: nil)
    update!(
      status: 'completed',
      transaction_id: transaction_id,
      gateway_response: gateway_response,
      processed_at: Time.current
    )
  end

  def mark_as_failed!(reason: nil, gateway_response: nil)
    update!(
      status: 'failed',
      failure_reason: reason,
      gateway_response: gateway_response,
      processed_at: Time.current
    )
  end

  def mark_as_cancelled!(reason: nil)
    update!(
      status: 'cancelled',
      failure_reason: reason,
      processed_at: Time.current
    )
  end

  def mark_as_refunded!(gateway_response: nil)
    update!(
      status: 'refunded',
      gateway_response: gateway_response,
      processed_at: Time.current
    )
  end

  def mark_as_partially_refunded!(gateway_response: nil)
    update!(
      status: 'partially_refunded',
      gateway_response: gateway_response,
      processed_at: Time.current
    )
  end

  def processing_time
    return nil unless processed_at

    processed_at - created_at
  end

  def gateway_data
    return {} if gateway_response.blank?

    JSON.parse(gateway_response)
  rescue JSON::ParserError
    {}
  end

  def metadata_data
    metadata || {}
  end

  # Payment history methods
  def payment_timeline
    return [] unless defined?(PaymentHistory)
    
    PaymentHistory.get_payment_timeline(self)
  rescue NameError, NoMethodError
    []
  end

  def recent_history(limit = 10)
    return [] unless respond_to?(:payment_histories)
    
    payment_histories.recent.limit(limit)
  rescue NoMethodError
    []
  end

  def status_change_history
    return [] unless respond_to?(:payment_histories)
    
    payment_histories.status_changes.recent
  rescue NoMethodError
    []
  end

  def refund_history
    return [] unless respond_to?(:payment_histories)
    
    payment_histories.refunds.recent
  rescue NoMethodError
    []
  end

  def failure_history
    return [] unless respond_to?(:payment_histories)
    
    payment_histories.failures.recent
  rescue NoMethodError
    []
  end

  def track_status_change(previous_status, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_status_change(self, previous_status, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_amount_update(previous_amount, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_amount_update(self, previous_amount, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_transaction_update(previous_transaction_id, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_transaction_update(self, previous_transaction_id, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_refund(refund_amount, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_refund(self, refund_amount, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_failure(failure_reason, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_failure(self, failure_reason, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_processing(performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_processing(self, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_gateway_response(gateway_response, performed_by: 'System', notes: nil)
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_gateway_response(self, gateway_response, performed_by: performed_by, notes: notes)
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  private

  def set_defaults
    self.currency ||= 'USD'
    self.status ||= 'pending'
  end

  def update_order_status
    case status
    when 'completed'
      order.update!(status: 'paid') if order.pending?
    when 'failed', 'cancelled'
      order.update!(status: 'payment_failed') if order.pending?
    when 'refunded'
      order.update!(status: 'refunded')
    when 'partially_refunded'
      order.update!(status: 'partially_refunded')
    end
  end

  def track_creation
    # PaymentHistory model may not exist, so we'll skip tracking in seeds
    return unless defined?(PaymentHistory)
    
    PaymentHistory.track_creation(self, performed_by: 'System', notes: 'Payment created')
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end

  def track_changes
    return unless defined?(PaymentHistory)
    
    # Track status changes
    if saved_change_to_status?
      previous_status = saved_changes['status'][0]
      track_status_change(previous_status, performed_by: 'System', notes: 'Status updated automatically')
    end

    # Track amount changes
    if saved_change_to_amount?
      previous_amount = saved_changes['amount'][0]
      track_amount_update(previous_amount, performed_by: 'System', notes: 'Amount updated')
    end

    # Track transaction ID changes
    if saved_change_to_transaction_id?
      previous_transaction_id = saved_changes['transaction_id'][0]
      track_transaction_update(previous_transaction_id, performed_by: 'System', notes: 'Transaction ID updated')
    end

    # Track gateway response changes
    return unless saved_change_to_gateway_response?

    track_gateway_response(gateway_response, performed_by: 'System', notes: 'Gateway response updated')
  rescue NameError, NoMethodError
    # Silently skip if PaymentHistory doesn't exist
  end
end
