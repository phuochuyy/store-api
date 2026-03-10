# frozen_string_literal: true

class PaymentHistorySerializer
  def initialize(payment_history)
    @payment_history = payment_history
  end

  def as_json
    {
      id: @payment_history.id,
      payment_id: @payment_history.payment_id,
      action: @payment_history.action,
      previous_status: @payment_history.previous_status,
      new_status: @payment_history.new_status,
      amount: @payment_history.amount&.to_f,
      transaction_id: @payment_history.transaction_id,
      gateway_response: @payment_history.gateway_response,
      performed_by: @payment_history.performed_by,
      performed_at: @payment_history.performed_at&.iso8601,
      notes: @payment_history.notes,
      metadata: @payment_history.metadata,
      status_transition: @payment_history.respond_to?(:status_transition) ? @payment_history.status_transition : nil,
      duration_since_previous: @payment_history.respond_to?(:duration_since_previous) ? @payment_history.duration_since_previous : nil,
      gateway_data: @payment_history.respond_to?(:gateway_data) ? @payment_history.gateway_data : nil,
      metadata_data: @payment_history.respond_to?(:metadata_data) ? @payment_history.metadata_data : nil,
      created_at: @payment_history.created_at&.iso8601,
      updated_at: @payment_history.updated_at&.iso8601
    }
  end
end
