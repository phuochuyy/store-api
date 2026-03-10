# frozen_string_literal: true

module Orders
  class OrderSerializerService
    class << self
      # Serialize order data
      # @param order [Order] Order to serialize
      # @return [Hash] Serialized order data
      def serialize_order(order)
        {
          id: order.id,
          customer_name: order.customer_name,
          customer_email: order.customer_email,
          customer_phone: order.customer_phone,
          total_amount: order.total_amount,
          status: order.status,
          tracking_number: order.tracking_number,
          carrier: order.carrier,
          shipped_at: order.shipped_at&.iso8601,
          delivered_at: order.delivered_at&.iso8601,
          delivery_notes: order.delivery_notes,
          delivery_signature: order.delivery_signature,
          shipping_status: order.shipping_status,
          estimated_delivery_date: order.estimated_delivery_date&.iso8601,
          created_at: order.created_at&.iso8601,
          updated_at: order.updated_at&.iso8601
        }
      end

      # Serialize order item data
      # @param order_item [OrderItem] Order item to serialize
      # @return [Hash] Serialized order item data
      def serialize_order_item(order_item)
        {
          id: order_item.id,
          product_id: order_item.product_id,
          product_name: order_item.product.name,
          quantity: order_item.quantity,
          unit_price: order_item.unit_price,
          total_price: order_item.total_price
        }
      end

      # Serialize pagination data
      # @param orders [ActiveRecord::Relation] Orders relation
      # @return [Hash] Serialized pagination data
      def serialize_pagination(orders)
        {
          current_page: orders.current_page,
          total_pages: orders.total_pages,
          total_count: orders.total_count,
          per_page: orders.limit_value
        }
      end
    end
  end
end
