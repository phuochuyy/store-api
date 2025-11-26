# frozen_string_literal: true

module Returns
  class ReturnProcessingService
    class << self
      # Create a return request
      # @param order [Order] The order to return
      # @param user [User] The user requesting return
      # @param return_items_params [Array<Hash>] Items to return
      # @param reason [String] Reason for return
      # @param return_type [String] 'refund' or 'exchange'
      # @return [Hash] Result with success status and return request
      def create_return_request(order, user, return_items_params, reason:, return_type: 'refund')
        return { success: false, error: 'Order not found' } unless order
        return { success: false, error: 'User not found' } unless user
        return { success: false, error: 'Order does not belong to user' } unless order.user_id == user.id
        return { success: false, error: 'Return items are required' } if return_items_params.blank?

        # Validate order can be returned
        validation_result = validate_order_for_return(order)
        return validation_result unless validation_result[:success]

        ActiveRecord::Base.transaction do
          return_request = ReturnRequest.create!(
            order: order,
            user: user,
            reason: reason,
            return_type: return_type,
            status: 'pending'
          )

          # Create return items
          return_items_params.each do |item_params|
            create_return_item(return_request, item_params)
          end

          # Calculate total refund amount
          return_request.update!(refund_amount: return_request.calculate_refund_amount)

          {
            success: true,
            return_request: return_request,
            message: 'Return request created successfully'
          }
        end
      rescue ActiveRecord::RecordInvalid => e
        {
          success: false,
          error: 'Failed to create return request',
          details: e.record.errors.full_messages
        }
      rescue StandardError => e
        Rails.logger.error "Return request creation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        {
          success: false,
          error: 'Failed to create return request',
          details: e.message
        }
      end

      # Process an approved return request
      # @param return_request [ReturnRequest] The return request to process
      # @param processed_by [User] Admin user processing the return
      # @return [Hash] Result with success status
      def process_return(return_request, processed_by: nil)
        return { success: false, error: 'Return request not found' } unless return_request
        return { success: false, error: 'Return request must be approved' } unless return_request.approved?

        ActiveRecord::Base.transaction do
          return_request.update!(status: 'processing')

          # Restore stock for returned items
          return_request.return_items.each do |return_item|
            restore_stock(return_item)
          end

          # Process refund if return type is refund
          if return_request.return_type == 'refund'
            process_refund(return_request)
          end

          # Mark as completed
          return_request.complete!

          {
            success: true,
            message: 'Return processed successfully',
            return_request: return_request
          }
        end
      rescue StandardError => e
        Rails.logger.error "Return processing error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        {
          success: false,
          error: 'Failed to process return',
          details: e.message
        }
      end

      private

      def validate_order_for_return(order)
        # Check if order is eligible for return (typically within 30 days)
        return { success: false, error: 'Order cannot be returned' } unless order.can_be_returned?

        # Check if order has been delivered
        return { success: false, error: 'Order must be delivered before return' } unless order.delivered?

        { success: true }
      end

      def create_return_item(return_request, item_params)
        order_item = OrderItem.find(item_params[:order_item_id])
        return unless order_item.order_id == return_request.order_id

        ReturnItem.create!(
          return_request: return_request,
          order_item: order_item,
          quantity: item_params[:quantity].to_i,
          reason: item_params[:reason],
          condition: item_params[:condition] || 'unopened'
        )
      end

      def restore_stock(return_item)
        order_item = return_item.order_item
        product = order_item.product
        variant = order_item.product_variant

        if variant
          variant.add_stock(return_item.quantity, reason: 'return_processed')
        else
          product.add_stock(return_item.quantity, reason: 'return_processed')
        end
      end

      def process_refund(return_request)
        # Integration with payment service to process refund
        # This would typically call the payment gateway API
        Rails.logger.info "Processing refund of #{return_request.refund_amount} for return request #{return_request.id}"
        # TODO: Integrate with actual payment refund service
        true
      end
    end
  end
end

