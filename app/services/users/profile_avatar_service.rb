# frozen_string_literal: true

module Users
  class ProfileAvatarService
    class << self
      # Upload user avatar
      # @param user [User] User to upload avatar for
      # @param avatar_file [File] Avatar file to upload
      # @return [Hash] Result with success status
      def upload_avatar(user:, avatar_file:)
        return { success: false, error: 'User not found' } unless user
        return { success: false, error: 'Avatar file is required' } unless avatar_file

        validation_result = validate_avatar_file(avatar_file)
        return validation_result unless validation_result[:success]

        upload_result = perform_avatar_upload?(user, avatar_file)
        build_avatar_response(user, upload_result)
      rescue StandardError => e
        Rails.logger.error "Avatar upload error: #{e.message}"
        {
          success: false,
          error: 'Failed to upload avatar',
          details: e.message
        }
      end

      # @param user [User] User to delete avatar for
      # @return [Hash] Result with success status
      def delete_avatar(user)
        return { success: false, error: 'User not found' } unless user

        if user.avatar.purge
          {
            success: true,
            message: 'Avatar deleted successfully'
          }
        else
          {
            success: false,
            error: 'Failed to delete avatar'
          }
        end
      rescue StandardError => e
        Rails.logger.error "Avatar deletion error: #{e.message}"
        {
          success: false,
          error: 'Failed to delete avatar',
          details: e.message
        }
      end

      private

      def validate_avatar_file(avatar_file)
        # Check file size (max 5MB)
        return { success: false, error: 'Avatar file is too large (max 5MB)' } if avatar_file.size > 5.megabytes

        # Check file type
        allowed_types = %w[image/jpeg image/png image/gif image/webp]
        unless allowed_types.include?(avatar_file.content_type)
          return { success: false, error: 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed' }
        end

        { success: true }
      end

      def perform_avatar_upload?(user, avatar_file)
        user.avatar.attach(avatar_file)
        user.avatar.attached?
      end

      def build_avatar_response(user, success)
        if success
          avatar_url = user.avatar.attached? ? Rails.application.routes.url_helpers.url_for(user.avatar) : nil
          {
            success: true,
            avatar_url: avatar_url,
            message: 'Avatar uploaded successfully'
          }
        else
          {
            success: false,
            error: 'Failed to upload avatar',
            details: user.errors.full_messages
          }
        end
      end
    end
  end
end
