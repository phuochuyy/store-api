# Payment gateway events already applied, so a redelivered event (gateways retry until they get
# a 2xx) is applied once. The unique index is what makes this hold under concurrent deliveries.
class CreatePaymentWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_webhook_events do |t|
      t.string :gateway, null: false, limit: 20
      t.string :event_id, null: false
      t.string :event_type
      t.references :payment, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :payment_webhook_events, %i[gateway event_id], unique: true
  end
end
