class CreateVariantOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :variant_options do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.string :option_type, null: false
      t.string :option_value, null: false

      t.timestamps
    end

    # Note: product_variant_id index is automatically created by t.references above
    add_index :variant_options, [:product_variant_id, :option_type]
  end
end
