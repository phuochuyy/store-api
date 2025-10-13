# frozen_string_literal: true

class PaymentHistorySerializer
  include JSONAPI::Serializer

  attributes :id, :action, :previous_status, :new_status, :amount, :transaction_id,
             :gateway_response, :performed_by, :performed_at, :notes, :metadata

  attribute :status_transition, &:status_transition

  attribute :duration_since_previous, &:duration_since_previous

  attribute :gateway_data, &:gateway_data

  attribute :metadata_data, &:metadata_data

  belongs_to :payment, serializer: PaymentSerializer
end
