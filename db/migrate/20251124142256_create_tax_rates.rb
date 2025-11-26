class CreateTaxRates < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_rates do |t|
      t.string :name, null: false
      t.string :country_code, null: false
      t.string :region
      t.references :category, foreign_key: true
      t.decimal :tax_rate, precision: 5, scale: 2, null: false
      t.string :tax_type, default: 'VAT', null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :tax_rates, :country_code
    add_index :tax_rates, [:country_code, :region]
    add_index :tax_rates, :is_active
    # Note: category_id index is automatically created by t.references above
  end
end
