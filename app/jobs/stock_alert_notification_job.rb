# frozen_string_literal: true

class StockAlertNotificationJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(stock_alert)
    return unless stock_alert.is_a?(StockAlert)

    result = send_notification(stock_alert)
    handle_notification_result(stock_alert, result)
  rescue StandardError => e
    handle_notification_error(stock_alert, e)
    raise e
  end

  private

  def send_notification(stock_alert)
    StockAlerts::StockNotificationService.send_stock_alert_notification(stock_alert)
  end

  def handle_notification_result(stock_alert, result)
    if result[:success]
      log_success(stock_alert, result)
    else
      log_error(stock_alert, result)
      raise StandardError, result[:error] if result[:error]
    end
  end

  def log_success(stock_alert, result)
    Rails.logger.info "Stock alert notification sent successfully for alert #{stock_alert.id}: #{result[:message]}"
  end

  def log_error(stock_alert, result)
    Rails.logger.error "Failed to send stock alert notification for alert #{stock_alert.id}: #{result[:error]}"
  end

  def handle_notification_error(stock_alert, error)
    Rails.logger.error "StockAlertNotificationJob failed for alert #{stock_alert&.id}: #{error.message}"
  end
end
