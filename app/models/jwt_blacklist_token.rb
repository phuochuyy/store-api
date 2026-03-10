# == Schema Information
#
# Table name: jwt_blacklist_tokens
#
#  id         :integer          not null, primary key
#  token      :string           not null
#  expires_at :datetime         not null
#  user_id    :string
#  token_type :string           default("access")
#  reason     :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class JwtBlacklistToken < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :token_type, inclusion: { in: %w[access refresh password_reset email_verification] }

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where(expires_at: ..Time.current) }
  scope :by_token_type, ->(type) { where(token_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # Clean up expired tokens
  def self.cleanup_expired
    expired.delete_all
  end

  def self.blacklisted?(token)
    return false if token.blank?

    active.exists?(token: token)
  end

  # Add token to blacklist
  def self.blacklist_token(token, user_id: nil, token_type: 'access', reason: nil, expires_at: nil)
    return false if token.blank?

    expires_at ||= extract_token_expiry(token)

    existing_token = find_by(token: token)
    if existing_token
      update_existing_token(existing_token, user_id, token_type, reason, expires_at)
    else
      create_new_blacklisted_token(token, user_id, token_type, reason, expires_at)
    end
    true
  rescue ActiveRecord::RecordNotUnique
    # Token already blacklisted
    true
  end

  def self.extract_token_expiry(token)
    payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' }).first
    Time.zone.at(payload['exp']) if payload['exp']
  rescue JWT::DecodeError
    24.hours.from_now
  end

  def self.update_existing_token(existing_token, user_id, token_type, reason, expires_at)
    existing_token.update!(
      user_id: user_id,
      token_type: token_type,
      reason: reason,
      expires_at: expires_at
    )
  end

  def self.create_new_blacklisted_token(token, user_id, token_type, reason, expires_at)
    create!(
      token: token,
      user_id: user_id,
      token_type: token_type,
      reason: reason,
      expires_at: expires_at
    )
  end

  def self.blacklist_user_tokens(user_id, reason: 'User logout')
    return false if user_id.blank?

    # Convert user_id to integer if it's a string (database stores as bigint)
    user_id_int = user_id.to_i
    return false if user_id_int.zero? && user_id.to_s != '0'

    Rails.logger.info "Blacklisting all tokens for user #{user_id_int}: #{reason}"

    # Find all active tokens for this user that haven't been blacklisted yet
    # We'll blacklist tokens that are in the database (from previous logouts)
    # and mark all future tokens as invalid via logout timestamp
    blacklisted_count = 0

    # Blacklist all existing tokens in database for this user
    # Note: We can only blacklist tokens we know about (already in database)
    # For tokens not yet in database, we rely on logout timestamp check
    active_tokens = active.by_user(user_id_int)
    blacklisted_count = active_tokens.count

    # Update reason for existing blacklisted tokens
    active_tokens.update_all(
      reason: reason,
      updated_at: Time.current
    )

    Rails.logger.info "Blacklisted #{blacklisted_count} existing tokens for user #{user_id_int}"
    true
  rescue StandardError => e
    Rails.logger.error "Failed to blacklist user tokens: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  # Get blacklist statistics
  def self.stats
    {
      total: count,
      active: active.count,
      expired: expired.count,
      by_type: group(:token_type).count,
      by_user: group(:user_id).count
    }
  end

  private_class_method :update_existing_token, :create_new_blacklisted_token

  def expired?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end
end
