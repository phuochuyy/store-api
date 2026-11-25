# frozen_string_literal: true

# A gateway event that has been applied (see Payments::PaymentWebhookService). The unique index on
# (gateway, event_id) is the idempotency guard; there is deliberately no uniqueness validation,
# so concurrent duplicates fail on the index rather than slip past a SELECT.
class PaymentWebhookEvent < ApplicationRecord
  belongs_to :payment, optional: true

  validates :gateway, :event_id, presence: true
end
