# frozen_string_literal: true

module StockAlerts
  class StockNotificationService
    class << self
      # Send notifications for stock alerts to admin users
      # @param stock_alert [StockAlert] The stock alert to send notification for
      # @return [Hash] Result with success status and notification details
      def send_stock_alert_notification(stock_alert)
        return { success: false, error: 'Stock alert not found' } unless stock_alert
        return { success: false, error: 'Stock alert already has notification sent' } if stock_alert.notification_sent?

        # Get admin users who should receive stock alerts
        admin_users = User.admin.where.not(id: nil)
        return { success: false, error: 'No admin users found' } if admin_users.empty?

        notifications_created = []
        errors = []

        admin_users.each do |admin_user|

          notification = Notification.create_stock_alert_notification(admin_user, stock_alert)
          notifications_created << notification
        rescue StandardError => e
          Rails.logger.error "Failed to create notification for admin #{admin_user.id}: #{e.message}"
          errors << "Admin #{admin_user.id}: #{e.message}"

        end

        # Mark stock alert as notification sent
        stock_alert.mark_notification_sent! if notifications_created.any?

        {
          success: notifications_created.any?,
          notifications_created: notifications_created.size,
          total_admins: admin_users.size,
          errors: errors,
          message: "#{notifications_created.size} notifications sent to admin users"
        }
      rescue StandardError => e
        Rails.logger.error "Stock notification service error: #{e.message}"
        {
          success: false,
          error: 'Failed to send stock alert notifications',
          details: e.message
        }
      end

      # Send bulk notifications for multiple stock alerts
      # @param stock_alerts [Array<StockAlert>] Array of stock alerts
      # @return [Hash] Result with success status and summary
      def send_bulk_stock_alert_notifications(stock_alerts)
        return { success: false, error: 'No stock alerts provided' } if stock_alerts.blank?

        results = {
          total_alerts: stock_alerts.size,
          notifications_sent: 0,
          alerts_processed: 0,
          errors: []
        }

        stock_alerts.each do |stock_alert|
          result = send_stock_alert_notification(stock_alert)
          results[:alerts_processed] += 1

          if result[:success]
            results[:notifications_sent] += result[:notifications_created]
          else
            results[:errors] << "Alert #{stock_alert.id}: #{result[:error]}"
          end
        end

        {
          success: results[:notifications_sent] > 0,
          results: results,
          message: "Processed #{results[:alerts_processed]} alerts, sent #{results[:notifications_sent]} notifications"
        }
      end

      # Send notifications for critical stock alerts only
      # @return [Hash] Result with success status and summary
      def send_critical_stock_alert_notifications
        critical_alerts = StockAlerts::StockMonitoringService.get_critical_alerts
        pending_alerts = critical_alerts.select { |alert| !alert.notification_sent? }

        return { success: true, message: 'No critical alerts pending notification' } if pending_alerts.empty?

        send_bulk_stock_alert_notifications(pending_alerts)
      end

      # Send daily stock alert summary to admin users
      # @return [Hash] Result with success status and summary
      def send_daily_stock_alert_summary
        summary = StockAlerts::StockMonitoringService.get_alert_summary
        admin_users = User.admin

        return { success: false, error: 'No admin users found' } if admin_users.empty?

        notifications_created = []
        errors = []

        admin_users.each do |admin_user|

          title = "Daily Stock Alert Summary - #{Date.current.strftime('%B %d, %Y')}"
          message = generate_daily_summary_message(summary)
          metadata = {
            summary_type: 'daily_stock_summary',
            date: Date.current.iso8601,
            total_alerts: summary[:total_alerts],
            active_alerts: summary[:active_alerts],
            critical_alerts: summary[:alerts_by_severity][:critical] || 0,
            high_alerts: summary[:alerts_by_severity][:high] || 0
          }

          notification = Notification.create_system_notification(admin_user, title, message, metadata)
          notifications_created << notification
        rescue StandardError => e
          Rails.logger.error "Failed to create daily summary for admin #{admin_user.id}: #{e.message}"
          errors << "Admin #{admin_user.id}: #{e.message}"

        end

        {
          success: notifications_created.any?,
          notifications_created: notifications_created.size,
          total_admins: admin_users.size,
          errors: errors,
          message: "#{notifications_created.size} daily summaries sent to admin users"
        }
      end

      # Send notifications for alerts pending notification
      # @return [Hash] Result with success status and summary
      def send_pending_notifications
        pending_alerts = StockAlerts::StockMonitoringService.get_alerts_pending_notification
        return { success: true, message: 'No alerts pending notification' } if pending_alerts.empty?

        send_bulk_stock_alert_notifications(pending_alerts)
      end

      # Get notification statistics
      # @param period [String] Time period for statistics
      # @return [Hash] Notification statistics
      def get_notification_statistics(period = 'week')
        start_date = case period
                     when 'day'
                       1.day.ago
                     when 'week'
                       1.week.ago
                     when 'month'
                       1.month.ago
                     when 'year'
                       1.year.ago
                     else
                       1.week.ago
                     end

        notifications = Notification.where(created_at: start_date..)

        {
          success: true,
          period: period,
          start_date: start_date,
          end_date: Time.current,
          statistics: {
            total_notifications: notifications.count,
            stock_alert_notifications: notifications.stock_alert.count,
            system_notifications: notifications.system_alert.count,
            unread_notifications: notifications.unread.count,
            read_notifications: notifications.read.count,
            notifications_by_type: notifications.group(:notification_type).count,
            notifications_by_user: notifications.joins(:user).group('users.role').count,
            average_notifications_per_day: (notifications.count / (Time.current - start_date) / 1.day).round(2)
          }
        }
      end

      private

      def generate_daily_summary_message(summary)
        message = "Daily Stock Alert Summary:\n\n"
        message += "📊 Total Alerts: #{summary[:total_alerts]}\n"
        message += "🚨 Active Alerts: #{summary[:active_alerts]}\n"
        message += "✅ Resolved Alerts: #{summary[:resolved_alerts]}\n"
        message += "❌ Dismissed Alerts: #{summary[:dismissed_alerts]}\n\n"

        message += "📈 Alerts by Type:\n"
        summary[:alerts_by_type].each do |type, count|
          message += "  • #{type.to_s.humanize}: #{count}\n"
        end

        message += "\n🎯 Alerts by Severity:\n"
        summary[:alerts_by_severity].each do |severity, count|
          emoji = case severity.to_s
                  when 'critical' then '🔴'
                  when 'high' then '🟠'
                  when 'medium' then '🟡'
                  when 'low' then '🔵'
                  else '⚪'
                  end
          message += "  #{emoji} #{severity.to_s.humanize}: #{count}\n"
        end

        message += "\n📦 Products with Alerts: #{summary[:products_with_alerts]}\n"

        if summary[:recent_alerts].any?
          message += "\n🕐 Recent Alerts:\n"
          summary[:recent_alerts].first(5).each do |alert_id, alert_type, product_id|
            message += "  • Alert ##{alert_id}: #{alert_type.to_s.humanize} (Product ##{product_id})\n"
          end
        end

        message
      end
    end
  end
end
