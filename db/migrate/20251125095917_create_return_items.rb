class CreateReturnItems < ActiveRecord::Migration[8.0]
  def change
    create_table :return_items do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :order_item, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.text :reason
      t.string :condition, default: 'unopened' # unopened, opened, damaged, defective
      t.decimal :refund_amount, precision: 10, scale: 2

      t.timestamps
    end

    # Note: return_request_id and order_item_id indexes are automatically created by t.references above
  end
end
