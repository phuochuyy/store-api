class AddWeightToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :weight, :decimal, precision: 10, scale: 2, default: 0.5
  end
end
