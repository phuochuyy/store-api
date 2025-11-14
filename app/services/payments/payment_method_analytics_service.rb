# frozen_string_literal: true

module Payments
  class PaymentMethodAnalyticsService
    class << self
      # @param payment_method [PaymentMethod] Payment method to analyze
      # @param period [String] Time period for statistics
      # @return [Hash] Payment method statistics
      def get_payment_method_stats(payment_method, period = 'month')
        return {} unless payment_method

        start_date = calculate_start_date(period)
        payments = payment_method.payments.where(created_at: start_date..)

        {
          total_transactions: payments.count,
          successful_transactions: payments.successful.count,
          failed_transactions: payments.failed.count,
          total_amount: payments.successful.sum(:amount),
          average_transaction_amount: calculate_average_amount(payments.successful),
          success_rate: calculate_success_rate(payments),
          refund_rate: calculate_refund_rate(payments),
          chargeback_rate: calculate_chargeback_rate(payments),
          period: period,
          start_date: start_date,
          end_date: Time.current
        }
      end

      # @param period [String] Time period for comparison
      # @return [Hash] Performance comparison data
      def get_payment_method_performance(period = 'month')
        start_date = calculate_start_date(period)
        payment_methods = PaymentMethod.active.includes(:payments)

        performance_data = payment_methods.map do |pm|
          payments = pm.payments.where(created_at: start_date..)
          {
            payment_method_id: pm.id,
            name: pm.name,
            gateway_type: pm.gateway_type,
            total_transactions: payments.count,
            successful_transactions: payments.successful.count,
            total_amount: payments.successful.sum(:amount),
            success_rate: calculate_success_rate(payments),
            average_amount: calculate_average_amount(payments.successful)
          }
        end

        performance_data.sort_by { |data| -data[:total_amount] }
      end

      # @param payment_method [PaymentMethod] Payment method to analyze
      # @param days [Integer] Number of days to analyze
      # @return [Hash] Trend data
      def get_payment_method_trends(payment_method, days = 30)
        return {} unless payment_method

        end_date = Time.current
        start_date = days.days.ago

        daily_data = (start_date.to_date..end_date.to_date).map do |date|
          day_payments = payment_method.payments.where(created_at: date.all_day)
          {
            date: date,
            transactions: day_payments.count,
            successful_transactions: day_payments.successful.count,
            amount: day_payments.successful.sum(:amount),
            success_rate: calculate_success_rate(day_payments)
          }
        end

        {
          payment_method_id: payment_method.id,
          payment_method_name: payment_method.name,
          period_days: days,
          daily_data: daily_data,
          summary: calculate_trend_summary(daily_data)
        }
      end

      private

      def calculate_start_date(period)
        case period
        when 'day'
          1.day.ago
        when 'week'
          1.week.ago
        when 'year'
          1.year.ago
        else
          1.month.ago # Default to month
        end
      end

      def calculate_average_amount(payments)
        return 0 if payments.empty?

        payments.sum(:amount) / payments.count.to_f
      end

      def calculate_success_rate(payments)
        return 0 if payments.empty?

        (payments.successful.count.to_f / payments.count * 100).round(2)
      end

      def calculate_refund_rate(payments)
        return 0 if payments.empty?

        (payments.refunded.count.to_f / payments.count * 100).round(2)
      end

      def calculate_chargeback_rate(payments)
        return 0 if payments.empty?

        chargeback_count = payments.where(status: 'chargeback').count
        (chargeback_count.to_f / payments.count * 100).round(2)
      end

      def calculate_trend_summary(daily_data)
        return {} if daily_data.empty?

        total_transactions = daily_data.sum { |day| day[:transactions] }
        total_amount = daily_data.sum { |day| day[:amount] }
        avg_success_rate = daily_data.sum { |day| day[:success_rate] } / daily_data.size

        {
          total_transactions: total_transactions,
          total_amount: total_amount,
          average_daily_transactions: (total_transactions.to_f / daily_data.size).round(2),
          average_daily_amount: (total_amount.to_f / daily_data.size).round(2),
          average_success_rate: avg_success_rate.round(2)
        }
      end
    end
  end
end
