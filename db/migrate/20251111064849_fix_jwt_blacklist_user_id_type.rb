class FixJwtBlacklistUserIdType < ActiveRecord::Migration[8.0]
  def up
    # Remove old index if exists
    remove_index :jwt_blacklist_tokens, :user_id if index_exists?(:jwt_blacklist_tokens, :user_id)
    
    # Change column type from string to bigint
    # First, convert existing string values to integers (nullify invalid ones)
    execute <<-SQL
      UPDATE jwt_blacklist_tokens
      SET user_id = NULL
      WHERE user_id IS NOT NULL
      AND user_id !~ '^[0-9]+$'
    SQL
    
    # Change column type
    change_column :jwt_blacklist_tokens, :user_id, :bigint, using: 'user_id::bigint'
    
    # Add foreign key constraint
    add_foreign_key :jwt_blacklist_tokens, :users, column: :user_id, on_delete: :nullify
    
    # Re-add index
    add_index :jwt_blacklist_tokens, :user_id
  end

  def down
    # Remove foreign key
    remove_foreign_key :jwt_blacklist_tokens, :users if foreign_key_exists?(:jwt_blacklist_tokens, :users)
    
    # Remove index
    remove_index :jwt_blacklist_tokens, :user_id if index_exists?(:jwt_blacklist_tokens, :user_id)
    
    # Change back to string
    change_column :jwt_blacklist_tokens, :user_id, :string
  end
end
