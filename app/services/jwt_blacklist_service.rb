# frozen_string_literal: true

class JwtBlacklistService
  class << self
    # Add a token to the blacklist
    # @param token [String] The JWT token to blacklist
    # @param user_id [String] User ID associated with the token
    # @param token_type [String] Type of token (access, refresh, etc.)
    # @param reason [String] Reason for blacklisting
    # @return [Boolean] True if successfully blacklisted
    def blacklist_token(token, user_id: nil, token_type: 'access', reason: nil)
      return false if token.blank?

      # Get token expiry from JWT payload
      expires_at = calculate_token_expiry(token)

      # Add to database
      JwtBlacklistToken.blacklist_token(
        token,
        user_id: user_id,
        token_type: token_type,
        reason: reason,
        expires_at: expires_at
      )

      Rails.logger.info "Token blacklisted: #{token[0..20]}..."
      true
    rescue StandardError => e
      Rails.logger.error "Failed to blacklist token: #{e.message}"
      false
    end

    # Check if a token is blacklisted
    # @param token [String] The JWT token to check
    # @return [Boolean] True if token is blacklisted
    def blacklisted?(token)
      return true if token.blank?

      JwtBlacklistToken.blacklisted?(token)
    rescue StandardError => e
      Rails.logger.error "Failed to check token blacklist: #{e.message}"
      # In case of database error, assume token is not blacklisted
      # This prevents false positives that would lock out users
      false
    end

    # Remove a token from the blacklist (useful for testing or admin operations)
    # @param token [String] The JWT token to remove from blacklist
    # @return [Boolean] True if successfully removed
    def whitelist_token(token)
      return false if token.blank?

      JwtBlacklistToken.where(token: token).delete_all
      Rails.logger.info "Token whitelisted: #{token[0..20]}..."
      true
    rescue StandardError => e
      Rails.logger.error "Failed to whitelist token: #{e.message}"
      false
    end

    # Get all blacklisted tokens (for admin purposes)
    # @return [Array<JwtBlacklistToken>] Array of blacklisted tokens
    def all_blacklisted_tokens
      JwtBlacklistToken.active.includes(:user)
    rescue StandardError => e
      Rails.logger.error "Failed to get blacklisted tokens: #{e.message}"
      []
    end

    # Clear all blacklisted tokens (for testing or maintenance)
    # @return [Integer] Number of tokens cleared
    def clear_all_blacklisted_tokens
      count = JwtBlacklistToken.count
      JwtBlacklistToken.delete_all
      Rails.logger.info "Cleared #{count} blacklisted tokens"
      count
    rescue StandardError => e
      Rails.logger.error "Failed to clear blacklisted tokens: #{e.message}"
      0
    end

    # Clean up expired tokens
    # @return [Integer] Number of tokens cleaned up
    def cleanup_expired_tokens
      JwtBlacklistToken.cleanup_expired
    rescue StandardError => e
      Rails.logger.error "Failed to cleanup expired tokens: #{e.message}"
      0
    end

    # Get blacklist statistics
    # @return [Hash] Statistics about blacklisted tokens
    def blacklist_stats
      JwtBlacklistToken.stats
    rescue StandardError => e
      Rails.logger.error "Failed to get blacklist stats: #{e.message}"
      { total: 0, active: 0, expired: 0, by_type: {}, by_user: {} }
    end

    # Blacklist all tokens for a user
    # @param user_id [String] User ID
    # @param reason [String] Reason for blacklisting
    # @return [Boolean] True if successful
    def blacklist_user_tokens(user_id, reason: 'User logout')
      JwtBlacklistToken.blacklist_user_tokens?(user_id, reason: reason)
    rescue StandardError => e
      Rails.logger.error "Failed to blacklist user tokens: #{e.message}"
      false
    end

    private

    # Calculate token expiry time
    # @param token [String] The JWT token
    # @return [DateTime] Token expiry time
    def calculate_token_expiry(token)
      # Try to get token expiry from JWT payload
      payload = JwtDecodeService.decode(token)
      return 24.hours.from_now unless payload&.dig('exp')

      # Convert Unix timestamp to DateTime
      Time.zone.at(payload['exp'])
    rescue StandardError
      # If we can't decode the token, use default expiry
      24.hours.from_now
    end
  end
end
