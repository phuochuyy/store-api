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
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :by_token_type, ->(type) { where(token_type: type) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # Clean up expired tokens
  def self.cleanup_expired
    expired.delete_all
  end

  # Check if token is blacklisted
  def self.blacklisted?(token)
    return false if token.blank?

    active.exists?(token: token)
  end

  # Add token to blacklist
  def self.blacklist_token(token, user_id: nil, token_type: 'access', reason: nil, expires_at: nil)
    return false if token.blank?

    # If no expires_at provided, try to decode token to get expiry
    if expires_at.nil?
      begin
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' }).first
        expires_at = Time.zone.at(payload['exp']) if payload['exp']
      rescue JWT::DecodeError
        # If we can't decode, set a default expiry
        expires_at = 24.hours.from_now
      end
    end

    # Check if token already exists
    existing_token = find_by(token: token)
    if existing_token
      # Update existing token if needed
      existing_token.update!(
        user_id: user_id,
        token_type: token_type,
        reason: reason,
        expires_at: expires_at
      )
      return true
    end

    create!(
      token: token,
      user_id: user_id,
      token_type: token_type,
      reason: reason,
      expires_at: expires_at
    )
  rescue ActiveRecord::RecordNotUnique
    # Token already blacklisted
    true
  end

  # Blacklist all tokens for a user
  def self.blacklist_user_tokens(user_id, reason: 'User logout')
    # This is a simplified implementation
    # In a real scenario, you might want to store user-specific token identifiers
    # and blacklist them individually
    Rails.logger.info "Blacklisting all tokens for user #{user_id}: #{reason}"
    true
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

  # Check if token is expired
  def expired?
    expires_at <= Time.current
  end

  # Check if token is active
  def active?
    !expired?
  end
end
