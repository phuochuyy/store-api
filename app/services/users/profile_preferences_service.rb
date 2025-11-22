# frozen_string_literal: true

module Users
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  class ProfilePreferencesService
    class << self
      # @param user [User] User to update
      # @param preferences [Hash] Preference parameters
      # @return [Hash] Result with success status
      def update_preferences(user:, **preferences)
        return { success: false, error: 'User not found' } unless user

        allowed_preferences = filter_allowed_preferences(preferences)
        validation_result = validate_preferences(allowed_preferences)
        return validation_result unless validation_result[:success]

        update_result = perform_preferences_update(user, allowed_preferences)
        build_preferences_response(user, update_result)
      rescue StandardError => e
        Rails.logger.error "Preferences update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update preferences',
          details: e.message
        }
      end

      private

      def filter_allowed_preferences(preferences)
        preferences.slice(
          :email_notifications_enabled, :sms_notifications_enabled,
          :marketing_emails_enabled, :language, :timezone,
          :currency, :theme, :privacy_level
        )
      end

      def validate_preferences(preferences)
        return { success: true } if preferences.empty?

        if preferences[:language].present?
          valid_languages = %w[en vi]
          return { success: false, error: 'Invalid language' } unless valid_languages.include?(preferences[:language])
        end

        if preferences[:timezone].present? && !ActiveSupport::TimeZone[preferences[:timezone]]
          return { success: false, error: 'Invalid timezone' }
        end

        if preferences[:currency].present?
          valid_currencies = %w[USD VND EUR]
          return { success: false, error: 'Invalid currency' } unless valid_currencies.include?(preferences[:currency])
        end

        if preferences[:theme].present?
          valid_themes = %w[light dark auto]
          return { success: false, error: 'Invalid theme' } unless valid_themes.include?(preferences[:theme])
        end

        if preferences[:privacy_level].present?
          valid_privacy_levels = %w[public friends private]
          unless valid_privacy_levels.include?(preferences[:privacy_level])
            return { success: false, error: 'Invalid privacy level' }
          end
        end

        { success: true }
      end

      def perform_preferences_update(user, preferences)
        user.update(preferences)
      end

      def build_preferences_response(user, success)
        if success
          {
            success: true,
            preferences: extract_user_preferences(user),
            message: 'Preferences updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update preferences',
            details: user.errors.full_messages
          }
        end
      end

      def extract_user_preferences(user)
        {
          email_notifications_enabled: user.email_notifications_enabled,
          sms_notifications_enabled: user.sms_notifications_enabled,
          marketing_emails_enabled: user.marketing_emails_enabled,
          language: user.language,
          timezone: user.timezone,
          currency: user.currency,
          theme: user.theme,
          privacy_level: user.privacy_level
        }
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
