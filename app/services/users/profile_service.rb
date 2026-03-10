# frozen_string_literal: true

module Users
  # Orchestrates user profile: get/update profile, preferences, avatar, deactivate, statistics, public profile.
  class ProfileService
    class << self
      # @param user [User] User to get profile for
      # @return [Hash] Result with profile data
      def get_profile(user)
        return { success: false, error: 'User not found' } unless user

        {
          success: true,
          profile: ProfileDataService.profile_data(user),
          message: 'Profile retrieved successfully'
        }
      end

      # @param user [User] User to update
      # @param profile_params [Hash] Profile parameters
      # @return [Hash] Result with success status
      def update_profile(user:, **profile_params)
        ProfileUpdateService.update_profile(user: user, **profile_params)
      end

      # @param user [User] User to update
      # @param preferences [Hash] Preference parameters
      # @return [Hash] Result with success status
      def update_preferences(user:, **preferences)
        ProfilePreferencesService.update_preferences(user: user, **preferences)
      end

      # Upload user avatar
      # @param user [User] User to upload avatar for
      # @param avatar_file [File] Avatar file to upload
      # @return [Hash] Result with success status
      def upload_avatar(user:, avatar_file:)
        ProfileAvatarService.upload_avatar(user: user, avatar_file: avatar_file)
      end

      # @param user [User] User to delete avatar for
      # @return [Hash] Result with success status
      delegate :delete_avatar, to: :ProfileAvatarService

      # Deactivate user account
      # @param user [User] User to deactivate
      # @param reason [String] Reason for deactivation
      # @return [Hash] Result with success status
      def deactivate_account(user:, reason: nil)
        return { success: false, error: 'User not found' } unless user

        deactivation_result = perform_account_deactivation?(user, reason)
        build_deactivation_response(deactivation_result)
      rescue StandardError => e
        Rails.logger.error "Account deactivation error: #{e.message}"
        {
          success: false,
          error: 'Failed to deactivate account',
          details: e.message
        }
      end

      # @param user [User] User to get statistics for
      # @return [Hash] Result with statistics
      def get_user_statistics(user)
        return { success: false, error: 'User not found' } unless user

        {
          success: true,
          statistics: ProfileDataService.user_statistics(user),
          message: 'Statistics retrieved successfully'
        }
      end

      # @param user [User] User to get public profile for
      # @return [Hash] Result with public profile data
      def get_public_profile(user)
        return { success: false, error: 'User not found' } unless user

        {
          success: true,
          profile: ProfileDataService.public_profile_data(user),
          message: 'Public profile retrieved successfully'
        }
      end

      private

      def perform_account_deactivation?(user, reason)
        user.update!(
          status: 'inactive',
          deactivated_at: Time.current,
          deactivation_reason: reason
        )
        true
      end

      def build_deactivation_response(success)
        if success
          {
            success: true,
            message: 'Account deactivated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to deactivate account'
          }
        end
      end
    end
  end
end
