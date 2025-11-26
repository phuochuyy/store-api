class CreateReturnRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :return_requests do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.text :reason
      t.datetime :requested_at
      t.datetime :processed_at
      t.decimal :refund_amount, precision: 10, scale: 2, default: 0.0
      t.string :return_type, default: 'refund' # refund, exchange
      t.text :admin_notes
      t.datetime :approved_at
      t.datetime :rejected_at
      t.text :rejection_reason

      t.timestamps
    end

    # Note: order_id and user_id indexes are automatically created by t.references above
    add_index :return_requests, :status
    add_index :return_requests, [:order_id, :status]
  end
end
