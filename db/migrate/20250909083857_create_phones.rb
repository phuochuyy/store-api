class CreatePhones < ActiveRecord::Migration[8.0]
  def change
    create_table :phones do |t|
      t.string :name
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.references :brand, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :stock_quantity
      t.string :image_url
      t.text :specifications

      t.timestamps
    end
  end
end
