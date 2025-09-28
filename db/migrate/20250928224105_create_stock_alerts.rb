class CreateStockAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_alerts do |t|
      t.references :product, null: false, foreign_key: true
      t.string :alert_type, null: false
      t.integer :threshold, null: false
      t.integer :current_stock, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at
      t.boolean :notification_sent, default: false, null: false
      t.text :message
      t.json :metadata

      t.timestamps
    end

    add_index :stock_alerts, :alert_type
    add_index :stock_alerts, :status
    add_index :stock_alerts, :triggered_at
    add_index :stock_alerts, :notification_sent
    add_index :stock_alerts, [:product_id, :alert_type, :status]
    add_index :stock_alerts, [:status, :notification_sent]
  end
end
