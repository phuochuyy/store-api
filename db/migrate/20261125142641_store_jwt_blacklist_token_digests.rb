# jwt_blacklist_tokens.token held the raw JWT in a string column. On MySQL that is VARCHAR(255),
# and real tokens are longer (about 270 characters for an access token), so every insert failed:
# logout and refresh token rotation silently revoked nothing. A SHA-256 digest is always 64
# characters, and the table no longer holds tokens that could be used if it leaked.
class StoreJwtBlacklistTokenDigests < ActiveRecord::Migration[8.1]
  class BlacklistEntry < ActiveRecord::Base
    self.table_name = 'jwt_blacklist_tokens'
  end

  def up
    add_column :jwt_blacklist_tokens, :token_digest, :string, limit: 64
    BlacklistEntry.reset_column_information

    # Expired entries no longer revoke anything (JwtCleanupJob deletes them daily anyway).
    BlacklistEntry.where(expires_at: ..Time.current).delete_all
    BlacklistEntry.find_each do |entry|
      entry.update_columns(token_digest: Digest::SHA256.hexdigest(entry.token))
    end

    change_column_null :jwt_blacklist_tokens, :token_digest, false
    add_index :jwt_blacklist_tokens, :token_digest, unique: true
    remove_index :jwt_blacklist_tokens, :token
    remove_column :jwt_blacklist_tokens, :token
  end

  # Best effort: tokens cannot be recovered from their digests, so the entries are dropped.
  # Tokens revoked before the rollback stay revoked only through Redis (the blacklist cache and
  # the per-user logout timestamp), until they expire.
  def down
    BlacklistEntry.delete_all
    remove_index :jwt_blacklist_tokens, :token_digest
    remove_column :jwt_blacklist_tokens, :token_digest
    add_column :jwt_blacklist_tokens, :token, :string, null: false
    add_index :jwt_blacklist_tokens, :token, unique: true
  end
end
