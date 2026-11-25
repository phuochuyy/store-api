# orders.status mixed two independent things: fulfillment (pending, confirmed, shipped,
# delivered, cancelled) and payment (paid, payment_failed, refunded, partially_refunded).
# A paid order could not be confirmed, a confirmed order could not be paid, and a refund
# overwrote the fulfillment state. Payment now gets its own column.
class SplitPaymentStatusFromOrderStatus < ActiveRecord::Migration[8.1]
  PAYMENT_STATES = %w[paid payment_failed refunded partially_refunded].freeze

  def up
    add_column :orders, :payment_status, :string, null: false, default: 'unpaid'
    add_index :orders, :payment_status

    payment_states = PAYMENT_STATES.map { |state| connection.quote(state) }.join(', ')

    # 1. Rows whose status held a payment state: move it to payment_status, then recover the
    #    fulfillment state from the lifecycle timestamps (most advanced first).
    execute <<~SQL.squish
      UPDATE orders SET payment_status = status WHERE status IN (#{payment_states})
    SQL
    execute <<~SQL.squish
      UPDATE orders SET status = CASE
        WHEN cancelled_at IS NOT NULL THEN 'cancelled'
        WHEN delivered_at IS NOT NULL THEN 'delivered'
        WHEN shipped_at IS NOT NULL THEN 'shipped'
        WHEN confirmed_at IS NOT NULL THEN 'confirmed'
        ELSE 'pending'
      END
      WHERE status IN (#{payment_states})
    SQL

    # 2. Rows that kept a fulfillment status but were paid anyway (e.g. through the admin
    #    status PATCH): a completed payment means the order is paid.
    execute <<~SQL.squish
      UPDATE orders SET payment_status = 'paid'
      WHERE payment_status = 'unpaid'
        AND EXISTS (SELECT 1 FROM payments WHERE payments.order_id = orders.id AND payments.status = 'completed')
    SQL
  end

  # Best effort: an order only goes back to a payment status when its fulfillment status is
  # still pending, because the old single column could not hold both.
  def down
    payment_states = PAYMENT_STATES.map { |state| connection.quote(state) }.join(', ')

    execute <<~SQL.squish
      UPDATE orders SET status = payment_status
      WHERE status = 'pending' AND payment_status IN (#{payment_states})
    SQL

    remove_index :orders, :payment_status
    remove_column :orders, :payment_status
  end
end
