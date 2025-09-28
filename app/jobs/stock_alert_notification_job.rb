# frozen_string_literal: true

class StockAlertNotificationJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(stock_alert)
    return unless stock_alert.is_a?(StockAlert)

    # Send notification for the stock alert
    result = StockAlerts::StockNotificationService.send_stock_alert_notification(stock_alert)

    if result[:success]
      Rails.logger.info "Stock alert notification sent successfully for alert #{stock_alert.id}: #{result[:message]}"
    else
      Rails.logger.error "Failed to send stock alert notification for alert #{stock_alert.id}: #{result[:error]}"
      raise StandardError, result[:error] if result[:error]
    end
  rescue StandardError => e
    Rails.logger.error "StockAlertNotificationJob failed for alert #{stock_alert&.id}: #{e.message}"
    raise e
  end
end
