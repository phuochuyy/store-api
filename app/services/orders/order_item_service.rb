# frozen_string_literal: true

module Orders
  # Admin changes to the items of an order after checkout. Stock moves with them, as it does when
  # the order is placed (OrderCreationService) or cancelled (OrderCancellationService), and only
  # while what the customer owes can still change (Order#amount_editable?). Each change runs under
  # the order's lock, and any failure rolls back both the item and the stock.
  class OrderItemService
    class Error < StandardError; end

    class << self
      # @return [Hash] { success: true, order_item: } or { success: false, error: }
      def add(order, product_id:, quantity:)
        change(order) do
          item = order.order_items.build(product_id: product_id, quantity: quantity)
          ensure_valid!(item)
          take_stock!(item, item.quantity)
          item.save!
          item
        end
      end

      def change_quantity(item, quantity)
        change(item.order) do
          added = quantity.to_i - item.quantity
          item.quantity = quantity
          ensure_valid!(item)
          added.positive? ? take_stock!(item, added) : give_stock_back!(item, -added)
          item.save!
          item
        end
      end

      def remove(item)
        change(item.order) do
          give_stock_back!(item, item.quantity)
          item.destroy!
          item
        end
      end

      private

      def change(order)
        item = order.with_lock do
          raise Error, Order::ITEMS_LOCKED_ERROR unless order.amount_editable?

          yield
        end
        { success: true, order_item: item }
      rescue Error => e
        { success: false, error: e.message }
      end

      def ensure_valid!(item)
        raise Error, item.errors.full_messages.to_sentence unless item.valid?
      end

      # The variant's stock when the item has one, as at checkout.
      def stock_holder(item)
        item.product_variant || item.product
      end

      def take_stock!(item, quantity)
        return if quantity.zero?
        return if stock_holder(item).reduce_stock(quantity, reason: 'order_item_changed')

        raise Error, "Not enough stock for #{item.product.name}"
      end

      def give_stock_back!(item, quantity)
        return if quantity.zero?
        return if stock_holder(item).add_stock(quantity, reason: 'order_item_changed')

        raise Error, "Could not restore stock for #{item.product.name}"
      end
    end
  end
end
