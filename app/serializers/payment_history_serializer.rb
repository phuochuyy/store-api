# frozen_string_literal: true

class PaymentHistorySerializer
  include JSONAPI::Serializer

  attributes :id, :action, :previous_status, :new_status, :amount, :transaction_id,
             :gateway_response, :performed_by, :performed_at, :notes, :metadata

  attribute :status_transition do |object|
    object.status_transition
  end

  attribute :duration_since_previous do |object|
    object.duration_since_previous
  end

  attribute :gateway_data do |object|
    object.gateway_data
  end

  attribute :metadata_data do |object|
    object.metadata_data
  end

  belongs_to :payment, serializer: PaymentSerializer
end
