# frozen_string_literal: true

module Api
  module V1
    class PaymentHistoriesController < Api::V1::BaseController
      before_action :authenticate_user!
      before_action :set_payment, only: %i[show timeline audit_trail]
      before_action :authorize_payment_history, only: %i[show timeline audit_trail]

      # GET /api/v1/payment_histories
      def index
        # Get payment history for the current user
        result = PaymentHistories::PaymentHistoryService.get_user_payment_history(
          current_user,
          {
            status: params[:status],
            payment_method_id: params[:payment_method_id],
            date_range: date_range_params,
            page: params[:page] || 1,
            per_page: params[:per_page] || 20
          }
        )

        if result[:success]
          render_success(result, 'Payment history retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/:payment_id
      def show
        result = PaymentHistories::PaymentHistoryService.get_payment_history(
          @payment,
          {
            limit: params[:limit] || 50,
            action: params[:action],
            date_range: date_range_params
          }
        )

        if result[:success]
          render_success(result, 'Payment history retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/:payment_id/timeline
      def timeline
        result = PaymentHistories::PaymentHistoryService.get_payment_timeline_analysis(@payment)

        if result[:success]
          render_success(result, 'Payment timeline analysis retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/:payment_id/audit_trail
      def audit_trail
        result = PaymentHistories::PaymentHistoryService.get_payment_audit_trail(@payment)

        if result[:success]
          render_success(result, 'Payment audit trail retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/statistics
      def statistics
        admin_only!

        options = {}
        options[:start_date] = params[:start_date]&.to_date if params[:start_date].present?
        options[:end_date] = params[:end_date]&.to_date if params[:end_date].present?
        options[:action] = params[:action_type] if params[:action_type].present?
        options[:performed_by] = params[:performed_by] if params[:performed_by].present?

        Rails.logger.debug { "Controller options: #{options.inspect}" }
        Rails.logger.debug { "Controller params: #{params.inspect}" }

        result = PaymentHistories::PaymentHistoryService.get_payment_history_statistics(options)

        Rails.logger.debug { "PaymentHistoryService result: #{result.inspect}" }

        if result[:success]
          render_success(result.except(:success), 'Payment history statistics retrieved successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/search
      def search
        query = params[:q]
        return render_error('Search query is required', :bad_request) if query.blank?

        result = PaymentHistories::PaymentHistoryService.search_payment_histories(
          query,
          {
            action: params[:action],
            start_date: params[:start_date]&.to_date,
            end_date: params[:end_date]&.to_date,
            page: params[:page] || 1,
            per_page: params[:per_page] || 20
          }
        )

        if result[:success]
          render_success(result, 'Payment history search completed successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/export
      def export
        admin_only!

        result = PaymentHistories::PaymentHistoryService.export_payment_history_data(
          {
            start_date: params[:start_date]&.to_date,
            end_date: params[:end_date]&.to_date
          }
        )

        if result[:success]
          render_success(result, 'Payment history data exported successfully')
        else
          render_error(result[:error], :unprocessable_entity)
        end
      end

      # GET /api/v1/payment_histories/my_recent
      def my_recent
        # Get recent payment history for current user
        recent_payments = Payment.joins(order: :user)
                                 .where(users: { id: current_user.id })
                                 .includes(:payment_histories, :payment_method, :order)
                                 .recent
                                 .limit(10)

        data = recent_payments.map do |payment|
          {
            payment: payment_serializer(payment),
            recent_history: payment.recent_history(3).map { |h| history_serializer(h) }
          }
        end

        render_success(
          {
            user_id: current_user.id,
            recent_payments: data,
            total_count: recent_payments.count
          },
          'Recent payment history retrieved successfully'
        )
      end

      # GET /api/v1/payment_histories/status_changes
      def status_changes
        # Get status changes for current user's payments
        status_changes = PaymentHistory.joins(payment: { order: :user })
                                       .where(users: { id: current_user.id })
                                       .status_changes
                                       .includes(:payment, payment: %i[order payment_method])
                                       .recent
                                       .limit(20)

        data = status_changes.map { |history| history_serializer(history) }

        render_success(
          {
            status_changes: data,
            total_count: status_changes.count
          },
          'Status changes retrieved successfully'
        )
      end

      # GET /api/v1/payment_histories/refunds
      def refunds
        # Get refund history for current user's payments
        refunds = PaymentHistory.joins(payment: { order: :user })
                                .where(users: { id: current_user.id })
                                .refunds
                                .includes(:payment, payment: %i[order payment_method])
                                .recent
                                .limit(20)

        data = refunds.map { |history| history_serializer(history) }

        render_success(
          {
            refunds: data,
            total_count: refunds.count
          },
          'Refund history retrieved successfully'
        )
      end

      # GET /api/v1/payment_histories/failures
      def failures
        # Get failure history for current user's payments
        failures = PaymentHistory.joins(payment: { order: :user })
                                 .where(users: { id: current_user.id })
                                 .failures
                                 .includes(:payment, payment: %i[order payment_method])
                                 .recent
                                 .limit(20)

        data = failures.map { |history| history_serializer(history) }

        render_success(
          {
            failures: data,
            total_count: failures.count
          },
          'Failure history retrieved successfully'
        )
      end

      private

      def set_payment
        @payment = Payment.find_by(id: params[:payment_id])
        render_error('Payment not found', :not_found) unless @payment
      end

      def authorize_payment_history
        # Users can only view their own payment history
        # Admins can view any payment history
        return if current_user.admin?

        # Check if the payment belongs to the current user
        return if @payment.order.user_id == current_user.id

        render_error('You are not authorized to view this payment history', :forbidden)
      end

      def date_range_params
        return nil unless params[:start_date].present? && params[:end_date].present?

        {
          start: params[:start_date].to_date,
          end: params[:end_date].to_date
        }
      end

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
    end
  end
end
