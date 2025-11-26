# frozen_string_literal: true

module Orders
  class OrderCreationService
    class << self
      # @param order_params [Hash] Order parameters
      # @param order_items_params [Array<Hash>] Order items parameters
      # @return [Hash] Result with success status and order information
      def create_order(order_params, order_items_params = [])
        # Perform order creation in transaction to ensure data consistency
        ActiveRecord::Base.transaction do
          order = build_and_save_order(order_params)
          process_order_items(order, order_items_params) if order_items_params.present?

          # Calculate and apply shipping cost if provided
          if order_params[:shipping_method_id].present? && order_params[:country_code].present?
            calculate_and_apply_shipping(order, order_params)
          end

          # Calculate and apply tax if country code provided
          calculate_and_apply_tax(order, order_params) if order_params[:country_code].present?

          order.update_total_amount

          build_success_response(order)
        end
      rescue ActiveRecord::RecordInvalid => e
        handle_validation_error(e)
      rescue StandardError => e
        handle_general_error(e)
      end

      private

      def build_and_save_order(order_params)
        order = Order.new(order_params)
        raise ActiveRecord::RecordInvalid, order unless order.save

        order
      end

      def process_order_items(order, order_items_params)
        order_items_params.each do |item_params|
          add_order_item(order, item_params)
        end
      end

      def add_order_item(order, item_params)
        product = Product.find(item_params[:product_id])
        quantity = item_params[:quantity].to_i
        variant = item_params[:product_variant_id].present? ? ProductVariant.find(item_params[:product_variant_id]) : nil

        # Validate variant belongs to product
        if variant && variant.product_id != product.id
          raise StandardError, "Variant does not belong to product #{product.name}"
        end

        # Validate stock availability (check variant stock if variant exists, otherwise product stock)
        validate_stock_availability(product, variant, quantity)

        create_order_item(order, product, variant, quantity)
        reduce_stock(product, variant, quantity, order)
      end

      def validate_stock_availability(product, variant, quantity)
        if variant
          return unless variant.stock_quantity < quantity

          error_message = "Insufficient stock for variant #{variant.name}. " \
                          "Available: #{variant.stock_quantity}, Requested: #{quantity}"
          raise StandardError, error_message
        else
          return unless product.stock_quantity < quantity

          error_message = "Insufficient stock for product #{product.name}. " \
                          "Available: #{product.stock_quantity}, Requested: #{quantity}"
          raise StandardError, error_message
        end
      end

      def create_order_item(order, product, variant, quantity)
        unit_price = variant ? variant.price : product.price
        order.order_items.create!(
          product: product,
          product_variant: variant,
          quantity: quantity,
          unit_price: unit_price
        )
      end

      def reduce_stock(product, variant, quantity, order)
        if variant
          result = variant.reduce_stock(quantity, reason: 'order_created')
          raise StandardError, "Failed to reduce stock for variant #{variant.name}" unless result
        else
          result = product.reduce_stock(quantity, reason: 'order_created', reference: order)
          raise StandardError, "Failed to reduce stock for product #{product.name}" unless result
        end
      end

      def build_success_response(order)
        {
          success: true,
          order: order,
          message: 'Order created successfully'
        }
      end

      def handle_validation_error(exception)
        Rails.logger.error "Order creation validation error: #{exception.message}"
        {
          success: false,
          error: 'Failed to create order',
          details: exception.record.errors.full_messages
        }
      end

      def handle_general_error(exception)
        Rails.logger.error "Order creation error: #{exception.message}"
        Rails.logger.error exception.backtrace.join("\n")
        {
          success: false,
          error: 'Failed to create order',
          details: exception.message
        }
      end

      def calculate_and_apply_shipping(order, order_params)
        shipping_result = Shipping::ShippingCostCalculatorService.calculate(
          order.order_items,
          shipping_method_id: order_params[:shipping_method_id],
          country_code: order_params[:country_code],
          region: order_params[:region]
        )

        if shipping_result[:success]
          order.update!(
            shipping_method_id: order_params[:shipping_method_id],
            shipping_cost: shipping_result[:shipping_cost],
            shipping_weight: shipping_result[:weight],
            shipping_address: order_params[:shipping_address]
          )
        else
          Rails.logger.warn "Failed to calculate shipping: #{shipping_result[:error]}"
        end
      end

      def calculate_and_apply_tax(order, order_params)
        tax_result = Tax::TaxCalculatorService.calculate(
          order.order_items,
          country_code: order_params[:country_code],
          region: order_params[:region]
        )

        if tax_result[:success]
          order.update!(
            tax_rate_id: tax_result[:tax_rate].id,
            tax_amount: tax_result[:tax_amount],
            tax_rate_value: tax_result[:tax_rate_value]
          )
        else
          Rails.logger.warn "Failed to calculate tax: #{tax_result[:error]}"
        end
      end

    end
  end
end
