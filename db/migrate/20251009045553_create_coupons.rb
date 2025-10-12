class CreateCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.references :discount, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true # Can be used by guest users
      t.references :order, null: true, foreign_key: true # Null until used
      t.datetime :used_at
      t.decimal :discount_amount, precision: 10, scale: 2 # Store actual discount applied
      t.string :status, default: 'active' # 'active', 'used', 'expired', 'cancelled'

      t.timestamps
    end

    add_index :coupons, :code, unique: true
    add_index :coupons, [:discount_id, :user_id]
    add_index :coupons, :status
    add_index :coupons, :used_at
  end
end
