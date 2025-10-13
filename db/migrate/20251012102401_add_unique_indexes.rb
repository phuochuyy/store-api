class AddUniqueIndexes < ActiveRecord::Migration[7.0]
  def change
    # Add unique index for brands name
    add_index :brands, :name, unique: true, name: 'index_brands_on_name_unique'

    # Add unique index for categories name
    add_index :categories, :name, unique: true, name: 'index_categories_on_name_unique'

    # Add unique index for users email
    add_index :users, :email, unique: true, name: 'index_users_on_email_unique'
  end
end