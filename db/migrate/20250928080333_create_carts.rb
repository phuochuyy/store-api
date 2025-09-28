class CreateCarts < ActiveRecord::Migration[8.0]
  def change
    create_table :carts do |t|
      t.references :user, null: true, foreign_key: true
      t.string :session_id, null: false
      t.string :status, default: 'active'
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :carts, :session_id
    add_index :carts, :status
    add_index :carts, [:user_id, :status]
  end
end
