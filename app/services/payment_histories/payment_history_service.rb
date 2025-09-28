# frozen_string_literal: true

module PaymentHistories
  class PaymentHistoryService
    class << self
      # Get payment histories with various filters
      # @param filters [Hash] Hash of filters (e.g., :payment_id, :action, :performed_by, :start_date, :end_date)
      # @return [ActiveRecord::Relation<PaymentHistory>] Filtered payment histories
      def get_histories(filters = {})
        histories = PaymentHistory.all.includes(payment: :order)

        histories = histories.where(payment_id: filters[:payment_id]) if filters[:payment_id].present?
        histories = histories.by_action(filters[:action]) if filters[:action].present?
        histories = histories.by_performed_by(filters[:performed_by]) if filters[:performed_by].present?
        if filters[:start_date].present? && filters[:end_date].present?
          histories = histories.where(performed_at: filters[:start_date]..filters[:end_date])
        end
        histories = histories.status_changes if filters[:status_changes]
        histories = histories.refunds if filters[:refunds]
        histories = histories.failures if filters[:failures]
        if filters[:user_id].present?
          histories = histories.joins(payment: :order).where(orders: { user_id: filters[:user_id] })
        end

        histories.order(performed_at: :desc)
      end

      # Get payment history for a specific payment
      # @param payment [Payment] The payment to get history for
      # @param options [Hash] Additional options
      # @return [Hash] Payment history data
      def get_payment_history(payment, options = {})
        return { success: false, error: 'Payment not found' } unless payment

        limit = options[:limit] || 50
        action_filter = options[:action]
        date_range = options[:date_range]

        histories = payment.payment_histories.includes(:payment)

        # Apply filters
        histories = histories.by_action(action_filter) if action_filter.present?
        histories = histories.by_date_range(date_range[:start], date_range[:end]) if date_range.present?

        histories = histories.recent.limit(limit)

        {
          success: true,
          payment_id: payment.id,
          payment_status: payment.status,
          payment_amount: payment.amount,
          total_history_count: payment.payment_histories.count,
          histories: histories.map { |history| history_serializer(history) },
          timeline: PaymentHistory.get_payment_timeline(payment)
        }
      end

      # Get payment history for a user
      # @param user [User] The user to get payment history for
      # @param options [Hash] Additional options
      # @return [Hash] User payment history data
      def get_user_payment_history(user, options = {})
        return { success: false, error: 'User not found' } unless user

        # Get payments for this user through orders
        payments = Payment.joins(order: :user).where(users: { id: user.id })

        # Apply filters
        payments = payments.where(status: options[:status]) if options[:status].present?

        if options[:payment_method_id].present?
          payments = payments.where(payment_method_id: options[:payment_method_id])
        end

        if options[:date_range].present?
          payments = payments.where(created_at: options[:date_range][:start]..options[:date_range][:end])
        end

        payments = payments.includes(:payment_histories, :payment_method, :order).recent

        # Pagination
        page = options[:page] || 1
        per_page = options[:per_page] || 20
        payments = payments.page(page).per(per_page)

        {
          success: true,
          user_id: user.id,
          user_email: user.email,
          total_payments: payments.total_count,
          payments: payments.map do |payment|
            {
              payment: payment_serializer(payment),
              recent_history: payment.recent_history(5).map { |h| history_serializer(h) },
              total_history_count: payment.payment_histories.count
            }
          end,
          pagination: {
            current_page: payments.current_page,
            total_pages: payments.total_pages,
            per_page: per_page
          }
        }
      end

      # Get payment history statistics
      # @param options [Hash] Filter options
      # @return [Hash] Payment history statistics
      def get_payment_history_statistics(options = {})
        start_date = options[:start_date] || 1.month.ago
        end_date = options[:end_date] || Time.current

        histories = PaymentHistory.where(performed_at: start_date..end_date)

        # Apply additional filters
        histories = histories.by_action(options[:action]) if options[:action].present?
        histories = histories.by_performed_by(options[:performed_by]) if options[:performed_by].present?

        {
          success: true,
          period: {
            start_date: start_date,
            end_date: end_date
          },
          total_actions: histories.count,
          actions_by_type: histories.group(:action).count,
          status_changes: histories.status_changes.count,
          refunds: histories.refunds.count,
          failures: histories.failures.count,
          most_active_performer: histories.group(:performed_by).count.max_by { |_, count| count },
          average_processing_time: calculate_average_processing_time(histories),
          timeline_data: generate_timeline_data(histories),
          top_payment_methods: get_top_payment_methods(histories),
          failure_analysis: analyze_failures(histories)
        }
      end

      # Get payment timeline for analytics
      # @param payment [Payment] The payment to analyze
      # @return [Hash] Detailed timeline analysis
      def get_payment_timeline_analysis(payment)
        return { success: false, error: 'Payment not found' } unless payment

        timeline = PaymentHistory.get_payment_timeline(payment)

        {
          success: true,
          payment_id: payment.id,
          total_duration: calculate_total_duration(timeline),
          status_transitions: extract_status_transitions(timeline),
          processing_stages: identify_processing_stages(timeline),
          bottlenecks: identify_bottlenecks(timeline),
          timeline: timeline
        }
      end

      # Search payment histories
      # @param query [String] Search query
      # @param options [Hash] Search options
      # @return [Hash] Search results
      def search_payment_histories(query, options = {})
        return { success: false, error: 'Search query is required' } if query.blank?

        histories = PaymentHistory.includes(:payment, payment: %i[order payment_method])

        # Text search
        histories = histories.where(
          'payment_histories.notes ILIKE ? OR payment_histories.transaction_id ILIKE ? OR payment_histories.performed_by ILIKE ?',
          "%#{query}%", "%#{query}%", "%#{query}%"
        )

        # Apply filters
        histories = histories.by_action(options[:action]) if options[:action].present?
        if options[:start_date].present? && options[:end_date].present?
          histories = histories.by_date_range(options[:start_date],
                                              options[:end_date])
        end

        # Pagination
        page = options[:page] || 1
        per_page = options[:per_page] || 20
        histories = histories.recent.page(page).per(per_page)

        {
          success: true,
          query: query,
          total_results: histories.total_count,
          results: histories.map { |history| history_serializer(history) },
          pagination: {
            current_page: histories.current_page,
            total_pages: histories.total_pages,
            per_page: per_page
          }
        }
      end

      # Get payment audit trail
      # @param payment [Payment] The payment to audit
      # @return [Hash] Complete audit trail
      def get_payment_audit_trail(payment)
        return { success: false, error: 'Payment not found' } unless payment

        {
          success: true,
          payment_id: payment.id,
          payment_details: payment_serializer(payment),
          complete_timeline: PaymentHistory.get_payment_timeline(payment),
          status_changes: payment.status_change_history.map { |h| history_serializer(h) },
          refunds: payment.refund_history.map { |h| history_serializer(h) },
          failures: payment.failure_history.map { |h| history_serializer(h) },
          gateway_interactions: payment.payment_histories.where(action: 'gateway_response_updated').map do |h|
            history_serializer(h)
          end,
          metadata_changes: payment.payment_histories.where(action: 'metadata_updated').map do |h|
            history_serializer(h)
          end,
          summary: {
            total_actions: payment.payment_histories.count,
            status_changes: payment.status_change_history.count,
            refunds: payment.refund_history.count,
            failures: payment.failure_history.count,
            first_action: payment.payment_histories.order(:performed_at).first&.performed_at,
            last_action: payment.payment_histories.order(:performed_at).last&.performed_at
          }
        }
      end

      # Export payment history data
      # @param options [Hash] Export options
      # @return [Hash] Export data
      def export_payment_history_data(options = {})
        start_date = options[:start_date] || 1.month.ago
        end_date = options[:end_date] || Time.current

        histories = PaymentHistory.includes(:payment, payment: %i[order payment_method])
                                  .where(performed_at: start_date..end_date)
                                  .order(:performed_at)

        {
          success: true,
          export_info: {
            generated_at: Time.current,
            date_range: { start_date: start_date, end_date: end_date },
            total_records: histories.count
          },
          data: histories.map do |history|
            {
              history_id: history.id,
              payment_id: history.payment_id,
              order_id: history.payment.order_id,
              customer_email: history.payment.order.customer_email,
              payment_method: history.payment.payment_method.name,
              action: history.action,
              previous_status: history.previous_status,
              new_status: history.new_status,
              amount: history.amount,
              transaction_id: history.transaction_id,
              performed_by: history.performed_by,
              performed_at: history.performed_at,
              notes: history.notes,
              gateway_response: history.gateway_response
            }
          end
        }
      end

      private

      def history_serializer(history)
        {
          id: history.id,
          action: history.action,
          previous_status: history.previous_status,
          new_status: history.new_status,
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

      def payment_serializer(payment)
        {
          id: payment.id,
          order_id: payment.order_id,
          payment_method_id: payment.payment_method_id,
          payment_method_name: payment.payment_method.name,
          amount: payment.amount,
          status: payment.status,
          currency: payment.currency,
          transaction_id: payment.transaction_id,
          processed_at: payment.processed_at,
          created_at: payment.created_at,
          updated_at: payment.updated_at
        }
      end

      def calculate_average_processing_time(histories)
        processing_histories = histories.where(action: 'processed')
        return 0 if processing_histories.empty?

        total_time = processing_histories.sum { |h| h.duration_since_previous || 0 }
        (total_time / processing_histories.count / 1.minute).round(2) # in minutes
      end

      def generate_timeline_data(histories)
        histories.group_by { |h| h.performed_at.to_date }
                 .transform_values(&:count)
                 .sort
                 .to_h
      end

      def get_top_payment_methods(histories)
        histories.joins(payment: :payment_method)
                 .group('payment_methods.name')
                 .count
                 .sort_by { |_, count| -count }
                 .first(5)
      end

      def analyze_failures(histories)
        failure_histories = histories.failures

        {
          total_failures: failure_histories.count,
          failure_rate: failure_histories.count.to_f / histories.count * 100,
          common_failure_reasons: failure_histories.joins(:payment)
                                                   .group('payments.failure_reason')
                                                   .count
                                                   .sort_by { |_, count| -count }
                                                   .first(5),
          failure_timeline: generate_timeline_data(failure_histories)
        }
      end

      def calculate_total_duration(timeline)
        return 0 if timeline.empty?

        first_action = timeline.first[:performed_at]
        last_action = timeline.last[:performed_at]

        (last_action - first_action) / 1.minute # in minutes
      end

      def extract_status_transitions(timeline)
        timeline.select { |entry| entry[:action] == 'status_changed' }
                .map { |entry| entry[:status_transition] }
      end

      def identify_processing_stages(timeline)
        stages = []
        current_stage = nil

        timeline.each do |entry|
          case entry[:action]
          when 'created'
            current_stage = 'created'
          when 'processed'
            current_stage = 'processing'
          when 'status_changed'
            if entry[:new_status] == 'completed'
              current_stage = 'completed'
            elsif %w[failed cancelled].include?(entry[:new_status])
              current_stage = 'failed'
            end
          when 'refunded'
            current_stage = 'refunded'
          end

          stages << {
            stage: current_stage,
            timestamp: entry[:performed_at],
            action: entry[:action]
          }
        end

        stages
      end

      def identify_bottlenecks(timeline)
        bottlenecks = []
        long_durations = timeline.select do |entry|
          entry[:duration_since_previous] && entry[:duration_since_previous] > 1.hour
        end

        long_durations.each do |entry|
          bottlenecks << {
            action: entry[:action],
            duration: entry[:duration_since_previous],
            timestamp: entry[:performed_at],
            notes: entry[:notes]
          }
        end

        bottlenecks
      end

      # Retrieves a chronological timeline for a specific payment
      # @param payment [Payment] The payment to get the timeline for
      # @return [Array<Hash>] An array of history events
      def get_payment_timeline(payment)
        PaymentHistory.get_payment_timeline(payment)
      end

      # Retrieves detailed audit trail for a specific payment history entry
      # @param payment_history [PaymentHistory] The history entry
      # @return [Hash] Audit trail details
      def get_audit_trail_details(payment_history)
        return { success: false, error: 'Payment history entry not found' } unless payment_history

        {
          success: true,
          id: payment_history.id,
          payment_id: payment_history.payment_id,
          action: payment_history.action,
          description: payment_history.message_for_timeline,
          previous_status: payment_history.previous_status,
          new_status: payment_history.new_status,
          amount: payment_history.amount,
          transaction_id: payment_history.transaction_id,
          gateway_response: payment_history.gateway_data,
          performed_by: payment_history.performed_by,
          performed_at: payment_history.performed_at,
          notes: payment_history.notes,
          metadata: payment_history.metadata_data,
          duration_since_previous: payment_history.duration_since_previous,
          created_at: payment_history.created_at,
          updated_at: payment_history.updated_at
        }
      rescue StandardError => e
        Rails.logger.error "Error retrieving audit trail for payment history #{payment_history.id}: #{e.message}"
        { success: false, error: "Error retrieving audit trail: #{e.message}" }
      end

      # Retrieves statistics about payment histories
      # @param start_date [Date] Optional start date for filtering
      # @param end_date [Date] Optional end date for filtering
      # @return [Hash] Statistics hash
      def get_statistics(start_date: nil, end_date: nil)
        PaymentHistory.get_payment_statistics(start_date: start_date, end_date: end_date)
      end

      # Exports payment history data
      # @param format [String] Export format (e.g., 'csv', 'json')
      # @param filters [Hash] Filters for the data
      # @return [String] Exported data
      def export_history(format: 'csv', filters: {})
        histories = get_histories(filters)

        case format.downcase
        when 'csv'
          generate_csv(histories)
        when 'json'
          histories.to_json(include: { payment: { include: :order } })
        else
          { success: false, error: 'Unsupported export format' }
        end
      rescue StandardError => e
        Rails.logger.error "Error exporting payment history: #{e.message}"
        { success: false, error: "Error exporting payment history: #{e.message}" }
      end

      private

      def generate_csv(histories)
        CSV.generate(headers: true) do |csv|
          csv << %w[ID PaymentID OrderID Action PreviousStatus NewStatus Amount Currency TransactionID PerformedBy
                    PerformedAt Notes]
          histories.each do |history|
            csv << [
              history.id,
              history.payment_id,
              history.payment.order_id,
              history.action,
              history.previous_status,
              history.new_status,
              history.amount,
              history.payment.currency,
              history.transaction_id,
              history.performed_by,
              history.performed_at,
              history.notes
            ]
          end
        end
      end
    end
  end
end
