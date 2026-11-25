# frozen_string_literal: true

module Api
  module V1
    module Payments
      # POST /api/v1/payments/webhooks/:gateway: payment events from the gateways. They carry no user
      # token; each event is authenticated by its signature instead (see Payments::PaymentWebhookService).
      class WebhooksController < Api::V1::BaseController
        skip_before_action :authenticate_user!

        def create
          result = ::Payments::PaymentProcessorService.receive_webhook(
            gateway: params[:gateway],
            raw_body: request.raw_post,
            signature: request.headers['X-Webhook-Signature']
          )
          return render_success(result[:body], 'Webhook received') if result[:status] == :ok

          render_error(result[:body][:error], result[:status])
        end
      end
    end
  end
end
