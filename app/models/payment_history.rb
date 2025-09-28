# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_histories
#
#  id               :integer          not null, primary key
#  payment_id       :integer          not null
#  action           :string           not null
#  previous_status  :string
#  new_status       :string
#  amount           :decimal(10, 2)
#  transaction_id   :string
#  gateway_response :text
#  performed_by     :string
#  performed_at     :datetime         not null
#  notes            :text
#  metadata         :json
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class PaymentHistory < ApplicationRecord
  # Associations
  belongs_to :payment

  # Validations
  validates :action, presence: true
  validates :performed_at, presence: true

  # Enums
  enum :action, {
    created: 'created',
    status_changed: 'status_changed',
    amount_updated: 'amount_updated',
    transaction_updated: 'transaction_updated',
    refunded: 'refunded',
    failed: 'failed',
    cancelled: 'cancelled',
    processed: 'processed',
    gateway_response_updated: 'gateway_response_updated',
    metadata_updated: 'metadata_updated'
  }

  # Scopes
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_performed_by, ->(user) { where(performed_by: user) }
  scope :by_date_range, ->(start_date, end_date) { where(performed_at: start_date..end_date) }
  scope :status_changes, -> { where(action: 'status_changed') }
  scope :refunds, -> { where(action: 'refunded') }
  scope :failures, -> { where(action: 'failed') }

  # Callbacks
  before_validation :set_defaults

  # Methods
  def status_change?
    action == 'status_changed'
  end

  def amount_change?
    action == 'amount_updated'
  end

  def transaction_change?
    action == 'transaction_updated'
  end

  def refund_action?
    action == 'refunded'
  end

  def failure_action?
    action == 'failed'
  end

  def processing_action?
    action == 'processed'
  end

  def created_action?
    action == 'created'
  end

  def status_transition
    return nil unless status_change?

    "#{previous_status} → #{new_status}"
  end

  def amount_difference
    return nil unless amount_change?

    # This would need to be calculated based on previous amount
    # For now, we'll return the current amount
    amount
  end

  def duration_since_previous
    return nil unless payment.payment_histories.count > 1

    previous_history = payment.payment_histories
                              .where('performed_at < ?', performed_at)
                              .order(performed_at: :desc)
                              .first

    return nil unless previous_history

    performed_at - previous_history.performed_at
  end

  def gateway_data
    return {} unless gateway_response.present?

    JSON.parse(gateway_response)
  rescue JSON::ParserError
    {}
  end

  def metadata_data
    metadata || {}
  end

  def self.create_history_entry(payment, action, options = {})
    create!(
      payment: payment,
      action: action,
      previous_status: options[:previous_status],
      new_status: options[:new_status] || payment.status,
      amount: options[:amount] || payment.amount,
      transaction_id: options[:transaction_id] || payment.transaction_id,
      gateway_response: options[:gateway_response] || payment.gateway_response,
      performed_by: options[:performed_by] || 'System',
      performed_at: options[:performed_at] || Time.current,
      notes: options[:notes],
      metadata: options[:metadata] || {}
    )
  end

  def self.track_status_change(payment, previous_status, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'status_changed',
      previous_status: previous_status,
      new_status: payment.status,
      performed_by: performed_by,
      notes: notes
    )
  end

  def self.track_amount_update(payment, previous_amount, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'amount_updated',
      amount: payment.amount,
      performed_by: performed_by,
      notes: notes,
      metadata: { previous_amount: previous_amount }
    )
  end

  def self.track_transaction_update(payment, previous_transaction_id, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'transaction_updated',
      transaction_id: payment.transaction_id,
      performed_by: performed_by,
      notes: notes,
      metadata: { previous_transaction_id: previous_transaction_id }
    )
  end

  def self.track_refund(payment, refund_amount, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'refunded',
      amount: refund_amount,
      performed_by: performed_by,
      notes: notes,
      metadata: { refund_amount: refund_amount, original_amount: payment.amount }
    )
  end

  def self.track_failure(payment, failure_reason, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'failed',
      performed_by: performed_by,
      notes: notes,
      metadata: { failure_reason: failure_reason }
    )
  end

  def self.track_processing(payment, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'processed',
      performed_by: performed_by,
      notes: notes
    )
  end

  def self.track_gateway_response(payment, gateway_response, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'gateway_response_updated',
      gateway_response: gateway_response,
      performed_by: performed_by,
      notes: notes
    )
  end

  def self.track_creation(payment, performed_by: 'System', notes: nil)
    create_history_entry(
      payment,
      'created',
      performed_by: performed_by,
      notes: notes
    )
  end

  def self.get_payment_timeline(payment)
    payment.payment_histories
           .includes(:payment)
           .order(:performed_at)
           .map do |history|
      {
        id: history.id,
        action: history.action,
        status_transition: history.status_transition,
        amount: history.amount,
        transaction_id: history.transaction_id,
        performed_by: history.performed_by,
        performed_at: history.performed_at,
        notes: history.notes,
        duration_since_previous: history.duration_since_previous,
        gateway_data: history.gateway_data,
        metadata: history.metadata_data
      }
    end
  end

  def self.get_user_payment_history(user_id, options = {})
    # This would need to be implemented based on how users are associated with payments
    # For now, we'll return all payment histories
    histories = PaymentHistory.includes(:payment)
                              .joins(payment: :order)
                              .where(orders: { customer_email: User.find(user_id).email })

    # Apply filters
    histories = histories.by_action(options[:action]) if options[:action].present?
    if options[:start_date].present? && options[:end_date].present?
      histories = histories.by_date_range(options[:start_date],
                                          options[:end_date])
    end

    histories.order(:performed_at)
  end

  def self.get_payment_statistics(options = {})
    start_date = options[:start_date] || 1.month.ago
    end_date = options[:end_date] || Time.current

    histories = where(performed_at: start_date..end_date)

    {
      total_actions: histories.count,
      actions_by_type: histories.group(:action).count,
      status_changes: histories.status_changes.count,
      refunds: histories.refunds.count,
      failures: histories.failures.count,
      most_active_performer: histories.group(:performed_by).count.max_by { |_, count| count },
      average_processing_time: calculate_average_processing_time(histories),
      timeline_data: generate_timeline_data(histories)
    }
  end

  private

  def set_defaults
    self.performed_at ||= Time.current
    self.performed_by ||= 'System'
  end

  def self.calculate_average_processing_time(histories)
    processing_histories = histories.where(action: 'processed')
    return 0 if processing_histories.empty?

    total_time = processing_histories.sum { |h| h.duration_since_previous || 0 }
    (total_time / processing_histories.count / 1.minute).round(2) # in minutes
  end

  def self.generate_timeline_data(histories)
    histories.group_by { |h| h.performed_at.to_date }
             .transform_values(&:count)
             .sort
             .to_h
  end
end
