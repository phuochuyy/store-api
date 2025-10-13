# frozen_string_literal: true

module Api
  module V1
    class PaymentsController < Api::V1::BaseController
      before_action :set_payment, only: %i[show update destroy refund]
      before_action :set_order, only: %i[create]
      before_action :admin_only!, only: %i[index update destroy refund]

      # GET /api/v1/payments
      def index
        @payments = build_payments_query
        data = build_payments_response
        render_success(data, 'Payments retrieved successfully')
      end

      private

      def build_payments_query
        payments = Payment.includes(:order, :payment_method)
                          .recent
                          .page(params[:page])
                          .per(params[:per_page] || 20)

        apply_payment_filters(payments)
      end

      def apply_payment_filters(payments)
        payments = payments.by_status(params[:status]) if params[:status].present?
        payments = payments.by_payment_method(params[:payment_method_id]) if params[:payment_method_id].present?

        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          payments = payments.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        end

        payments
      end

      def build_payments_response
        {
          payments: @payments.map { |payment| payment_serializer(payment) },
          pagination: {
            current_page: @payments.current_page,
            total_pages: @payments.total_pages,
            total_count: @payments.total_count,
            per_page: @payments.limit_value
          }
        }
      end

      # GET /api/v1/payments/:id
      def show
        data = {
          payment: payment_serializer(@payment),
          order: order_serializer(@payment.order),
          payment_method: payment_method_serializer(@payment.payment_method)
        }

        render_success(data, 'Payment retrieved successfully')
      end

      # POST /api/v1/payments
      def create
        return render_error('Order not found', :not_found) unless @order
        return render_error('Order cannot be paid', :unprocessable_entity) unless @order.can_be_paid?

        payment_method = PaymentMethod.find_by(id: payment_params[:payment_method_id])
        return render_error('Payment method not found', :not_found) unless payment_method

        result = Payments::PaymentProcessorService.process_payment(
          order: @order,
          payment_method: payment_method,
          payment_data: payment_params[:payment_data] || {}
        )

        if result[:success]
          payment = Payment.find_by(order: @order, payment_method: payment_method)
          data = {
            payment: payment_serializer(payment),
            order: order_serializer(@order)
          }
          render_success(data, result[:message] || 'Payment processed successfully', :created)
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # PATCH/PUT /api/v1/payments/:id
      def update
        if @payment.update(payment_update_params)
          data = { payment: payment_serializer(@payment) }
          render_success(data, 'Payment updated successfully')
        else
          render_error('Payment could not be updated', :unprocessable_entity, @payment.errors.full_messages)
        end
      end

      # DELETE /api/v1/payments/:id
      def destroy
        if @payment.pending?
          @payment.destroy
          render_success(nil, 'Payment deleted successfully')
        else
          render_error('Only pending payments can be deleted', :unprocessable_entity)
        end
      end

      # POST /api/v1/payments/:id/refund
      def refund
        return render_error('Payment cannot be refunded', :unprocessable_entity) unless @payment.can_be_refunded?

        refund_amount = refund_params[:amount]&.to_f
        refund_reason = refund_params[:reason]

        result = Payments::PaymentProcessorService.refund_payment(
          payment: @payment,
          amount: refund_amount,
          reason: refund_reason
        )

        if result[:success]
          @payment.reload
          data = { payment: payment_serializer(@payment) }
          render_success(data, result[:message] || 'Refund processed successfully')
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      def set_payment
        @payment = Payment.find_by(id: params[:id])
        render_error('Payment not found', :not_found) unless @payment
      end

      def set_order
        @order = Order.find_by(id: params[:order_id])
      end

      def payment_params
        params.expect(
          payment: [:payment_method_id,
                    { payment_data: {} }]
        )
      end

      def payment_update_params
        params.expect(
          payment: [:status,
                    :transaction_id,
                    :gateway_response,
                    :failure_reason,
                    { metadata: {} }]
        )
      end

      def refund_params
        params.expect(refund: %i[amount reason])
      end

      def payment_serializer(payment)
        {
          id: payment.id,
          amount: payment.amount,
          processing_fee: payment.processing_fee,
          total_amount: payment.total_amount,
          status: payment.status,
          transaction_id: payment.transaction_id,
          currency: payment.currency,
          processed_at: payment.processed_at,
          failure_reason: payment.failure_reason,
          created_at: payment.created_at,
          updated_at: payment.updated_at,
          payment_method: {
            id: payment.payment_method.id,
            name: payment.payment_method.name,
            gateway_type: payment.payment_method.gateway_type
          },
          order: {
            id: payment.order.id,
            customer_name: payment.order.customer_name,
            customer_email: payment.order.customer_email,
            total_amount: payment.order.total_amount,
            status: payment.order.status
          }
        }
      end

      def order_serializer(order)
        {
          id: order.id,
          customer_name: order.customer_name,
          customer_email: order.customer_email,
          customer_phone: order.customer_phone,
          total_amount: order.total_amount,
          status: order.status,
          payment_status: order.payment_status,
          total_paid_amount: order.total_paid_amount,
          created_at: order.created_at,
          updated_at: order.updated_at
        }
      end

      def payment_method_serializer(payment_method)
        {
          id: payment_method.id,
          name: payment_method.name,
          description: payment_method.description,
          gateway_type: payment_method.gateway_type,
          processing_fee_percentage: payment_method.processing_fee_percentage,
          processing_fee_fixed: payment_method.processing_fee_fixed,
          is_active: payment_method.is_active
        }
      end
    end
  end
end
