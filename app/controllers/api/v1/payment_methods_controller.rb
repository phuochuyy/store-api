# frozen_string_literal: true

module Api
  module V1
    class PaymentMethodsController < Api::V1::BaseController
      before_action :set_payment_method, only: %i[show update destroy stats]
      before_action :admin_only!, only: %i[create update destroy stats]

      def index
        @payment_methods = Payments::PaymentMethodService.get_active_payment_methods

        # Filter by gateway type if provided
        @payment_methods = @payment_methods.by_gateway_type(params[:gateway_type]) if params[:gateway_type].present?

        data = {
          payment_methods: @payment_methods.map { |method| payment_method_serializer(method) }
        }

        render_success(data, 'Payment methods retrieved successfully')
      end

      def show
        data = {
          payment_method: payment_method_serializer(@payment_method)
        }

        render_success(data, 'Payment method retrieved successfully')
      end

      def create
        result = Payments::PaymentMethodService.create_payment_method(payment_method_params)

        if result[:success]
          data = {
            payment_method: payment_method_serializer(result[:payment_method])
          }
          render_success(data, result[:message], :created)
        else
          render_error(result[:message], :unprocessable_content, result[:errors])
        end
      end

      def update
        result = Payments::PaymentMethodService.update_payment_method(@payment_method, payment_method_params)

        if result[:success]
          data = {
            payment_method: payment_method_serializer(result[:payment_method])
          }
          render_success(data, result[:message])
        else
          render_error(result[:message], :unprocessable_content, result[:errors])
        end
      end

      def destroy
        result = Payments::PaymentMethodService.deactivate_payment_method(@payment_method)

        if result[:success]
          render_success(nil, result[:message])
        else
          render_error(result[:message], :unprocessable_content, result[:errors])
        end
      end

      def stats
        period = params[:period] || 'month'
        result = Payments::PaymentMethodService.get_payment_method_stats(@payment_method, period)

        if result[:success]
          data = {
            payment_method: payment_method_serializer(@payment_method),
            stats: result[:stats],
            period: result[:period],
            start_date: result[:start_date],
            end_date: result[:end_date]
          }
          render_success(data, 'Payment method statistics retrieved successfully')
        else
          render_error(result[:error], :unprocessable_content, result[:details])
        end
      end

      def calculate_fees
        amount = params[:amount]&.to_f
        payment_method_id = params[:payment_method_id]

        return render_error('Amount is required', :bad_request) unless amount&.positive?
        return render_error('Payment method ID is required', :bad_request) unless payment_method_id

        payment_method = PaymentMethod.find_by(id: payment_method_id)
        return render_error('Payment method not found', :not_found) unless payment_method

        result = Payments::PaymentMethodService.calculate_processing_fees(amount, payment_method)

        if result[:success]
          data = {
            original_amount: result[:original_amount],
            processing_fee: result[:processing_fee],
            total_amount: result[:total_amount],
            fee_breakdown: result[:fee_breakdown],
            payment_method: payment_method_serializer(payment_method)
          }
          render_success(data, 'Processing fees calculated successfully')
        else
          render_error(result[:error], :unprocessable_content, result[:details])
        end
      end

      def validate_config
        result = Payments::PaymentMethodService.validate_payment_method_config(@payment_method)

        data = {
          payment_method: payment_method_serializer(@payment_method),
          is_valid: result[:success],
          errors: result[:errors]
        }

        if result[:success]
          render_success(data, result[:message])
        else
          render_error(result[:message], :unprocessable_content, result[:errors])
        end
      end

      private

      def set_payment_method
        @payment_method = PaymentMethod.find_by(id: params[:id])
        render_error('Payment method not found', :not_found) unless @payment_method
      end

      def payment_method_params
        params.expect(
          payment_method: [:name,
                           :description,
                           :gateway_type,
                           :processing_fee_percentage,
                           :processing_fee_fixed,
                           :is_active,
                           { gateway_config: {} }]
        )
      end

      def payment_method_serializer(payment_method)
        {
          id: payment_method.id,
          name: payment_method.name,
          description: payment_method.description,
          gateway_type: payment_method.gateway_type,
          processing_fee_percentage: payment_method.processing_fee_percentage,
          processing_fee_fixed: payment_method.processing_fee_fixed,
          is_active: payment_method.is_active,
          supports_refunds: payment_method.supports_refunds?,
          supports_partial_refunds: payment_method.supports_partial_refunds?,
          gateway_configured: payment_method.gateway_configured?,
          created_at: payment_method.created_at,
          updated_at: payment_method.updated_at
        }
      end
    end
  end
end
