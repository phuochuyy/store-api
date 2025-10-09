class CreateJwtBlacklistTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :jwt_blacklist_tokens do |t|
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.string :user_id
      t.string :token_type, default: 'access'
      t.text :reason

      t.timestamps
    end
    
    add_index :jwt_blacklist_tokens, :token, unique: true
    add_index :jwt_blacklist_tokens, :expires_at
    add_index :jwt_blacklist_tokens, :user_id
    add_index :jwt_blacklist_tokens, :token_type
  end
end
