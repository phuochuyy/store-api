# frozen_string_literal: true

module Api
  module V1
    class ReturnsController < Api::V1::BaseController
      before_action :set_return_request, only: %i[show cancel approve reject complete]

      # GET /api/v1/returns
      def index
        return_requests = current_user.return_requests.includes(:order, :return_items).order(created_at: :desc)
        render_success(return_requests.map { |r| return_request_serializer(r) }, 'Return requests retrieved successfully')
      end

      # GET /api/v1/returns/:id
      def show
        render_success(return_request_serializer(@return_request), 'Return request retrieved successfully')
      end

      # POST /api/v1/returns
      def create
        order = Order.find_by(id: params[:order_id], user_id: current_user.id)
        return render_error('Order not found', :not_found) unless order

        result = ::Returns::ReturnProcessingService.create_return_request(
          order,
          current_user,
          params[:return_items] || [],
          reason: params[:reason],
          return_type: params[:return_type] || 'refund'
        )

        if result[:success]
          render_success(return_request_serializer(result[:return_request]), result[:message], :created)
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      # PATCH /api/v1/returns/:id/cancel
      def cancel
        if @return_request.cancel!
          render_success(return_request_serializer(@return_request), 'Return request cancelled successfully')
        else
          render_error('Cannot cancel this return request', :unprocessable_entity)
        end
      end

      # PATCH /api/v1/returns/:id/approve (admin only)
      def approve
        authorize! :update, @return_request

        if @return_request.approve!(admin_notes: params[:admin_notes])
          render_success(return_request_serializer(@return_request), 'Return request approved successfully')
        else
          render_error('Cannot approve this return request', :unprocessable_entity)
        end
      end

      # PATCH /api/v1/returns/:id/reject (admin only)
      def reject
        authorize! :update, @return_request

        rejection_reason = params[:rejection_reason]
        return render_error('Rejection reason is required', :bad_request) if rejection_reason.blank?

        if @return_request.reject!(rejection_reason)
          render_success(return_request_serializer(@return_request), 'Return request rejected successfully')
        else
          render_error('Cannot reject this return request', :unprocessable_entity)
        end
      end

      # PATCH /api/v1/returns/:id/complete (admin only)
      def complete
        authorize! :update, @return_request

        result = ::Returns::ReturnProcessingService.process_return(@return_request, processed_by: current_user)

        if result[:success]
          render_success(return_request_serializer(result[:return_request]), result[:message])
        else
          render_error(result[:error], :unprocessable_entity, result[:details])
        end
      end

      private

      def set_return_request
        @return_request = ReturnRequest.find(params[:id])
        # Users can only access their own return requests unless admin
        unless current_user.admin? || @return_request.user_id == current_user.id
          render_error('Return request not found', :not_found)
        end
      rescue ActiveRecord::RecordNotFound
        render_error('Return request not found', :not_found)
      end

      def return_request_serializer(return_request)
        {
          id: return_request.id,
          order_id: return_request.order_id,
          status: return_request.status,
          return_type: return_request.return_type,
          reason: return_request.reason,
          refund_amount: return_request.refund_amount.to_f,
          total_quantity: return_request.total_quantity,
          requested_at: return_request.requested_at,
          processed_at: return_request.processed_at,
          approved_at: return_request.approved_at,
          rejected_at: return_request.rejected_at,
          rejection_reason: return_request.rejection_reason,
          admin_notes: return_request.admin_notes,
          return_items: return_request.return_items.map do |item|
            {
              id: item.id,
              order_item_id: item.order_item_id,
              quantity: item.quantity,
              reason: item.reason,
              condition: item.condition,
              refund_amount: item.refund_amount.to_f
            }
          end
        }
      end
    end
  end
end

