# frozen_string_literal: true

module Users
  class ProfileService
    class << self
      # Get user profile
      # @param user [User] User to get profile for
      # @return [Hash] Result with profile data
      def get_profile(user)
        return { success: false, error: 'User not found' } unless user

        {
          success: true,
          profile: profile_data(user),
          message: 'Profile retrieved successfully'
        }
      end

      # Update user profile
      # @param user [User] User to update
      # @param profile_params [Hash] Profile parameters
      # @return [Hash] Result with success status
      def update_profile(user:, **profile_params)
        return { success: false, error: 'User not found' } unless user

        # Filter allowed parameters
        allowed_params = profile_params.slice(
          :first_name, :last_name, :phone, :date_of_birth,
          :gender, :bio, :avatar
        )

        # Validate date of birth
        if allowed_params[:date_of_birth].present?
          begin
            allowed_params[:date_of_birth] = Date.parse(allowed_params[:date_of_birth].to_s)
            # Check if date is not in the future
            if allowed_params[:date_of_birth] > Date.current
              return { success: false, error: 'Date of birth cannot be in the future' }
            end
            # Check if user is at least 13 years old
            if allowed_params[:date_of_birth] > 13.years.ago.to_date
              return { success: false, error: 'You must be at least 13 years old' }
            end
          rescue ArgumentError
            return { success: false, error: 'Invalid date format' }
          end
        end

        # Update user profile
        if user.update(allowed_params)
          {
            success: true,
            profile: profile_data(user),
            message: 'Profile updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update profile',
            details: user.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Profile update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update profile',
          details: e.message
        }
      end

      # Update user preferences
      # @param user [User] User to update preferences for
      # @param preferences [Hash] New preferences
      # @return [Hash] Result with success status
      def update_preferences(user:, **preferences)
        return { success: false, error: 'User not found' } unless user

        # Validate notification preferences
        if preferences[:notifications].present?
          notification_prefs = preferences[:notifications]
          valid_notification_types = %w[email push sms]

          notification_prefs.each do |type, value|
            unless valid_notification_types.include?(type.to_s)
              return { success: false, error: "Invalid notification type: #{type}" }
            end
            unless [true, false].include?(value)
              return { success: false, error: "Invalid notification value for #{type}" }
            end
          end
        end

        # Update preferences
        current_preferences = user.preferences || {}
        current_preferences.merge!(preferences)

        if user.update(preferences: current_preferences)
          {
            success: true,
            preferences: user.preferences,
            message: 'Preferences updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update preferences',
            details: user.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Preferences update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update preferences',
          details: e.message
        }
      end

      # Upload user avatar
      # @param user [User] User to upload avatar for
      # @param avatar_file [File] Avatar file
      # @return [Hash] Result with success status
      def upload_avatar(user:, avatar_file:)
        return { success: false, error: 'User not found' } unless user
        return { success: false, error: 'Avatar file is required' } unless avatar_file

        # Validate file type
        allowed_types = %w[image/jpeg image/png image/gif image/webp]
        unless allowed_types.include?(avatar_file.content_type)
          return { success: false, error: 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed' }
        end

        # Validate file size (max 5MB)
        max_size = 5.megabytes
        return { success: false, error: 'File size too large. Maximum size is 5MB' } if avatar_file.size > max_size

        # Generate unique filename
        filename = "#{user.id}_#{Time.current.to_i}_#{avatar_file.original_filename}"

        # In a real implementation, you would upload to cloud storage
        # For now, we'll just store the filename
        if user.update(avatar: filename)
          {
            success: true,
            avatar_url: "/uploads/avatars/#{filename}",
            message: 'Avatar uploaded successfully'
          }
        else
          {
            success: false,
            error: 'Failed to upload avatar',
            details: user.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Avatar upload error: #{e.message}"
        {
          success: false,
          error: 'Failed to upload avatar',
          details: e.message
        }
      end

      # Delete user avatar
      # @param user [User] User to delete avatar for
      # @return [Hash] Result with success status
      def delete_avatar(user)
        return { success: false, error: 'User not found' } unless user

        if user.update(avatar: nil)
          {
            success: true,
            message: 'Avatar deleted successfully'
          }
        else
          {
            success: false,
            error: 'Failed to delete avatar',
            details: user.errors.full_messages
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

      # Get profile statistics
      # @param user [User] User to get statistics for
      # @return [Hash] Profile statistics
      def get_profile_statistics(user)
        return { success: false, error: 'User not found' } unless user

        {
          success: true,
          statistics: {
            profile_completion: user.profile_completion_percentage,
            profile_complete: user.profile_complete?,
            account_age: (Time.current - user.created_at).to_i / 1.day,
            total_orders: user.orders.count,
            total_reviews: user.product_reviews.count,
            total_wishlist_items: user.product_wishlists.count,
            address_count: user.address_count,
            last_login: user.updated_at
          }
        }
      end

      # Deactivate user account
      # @param user [User] User to deactivate
      # @param reason [String] Reason for deactivation
      # @return [Hash] Result with success status
      def deactivate_account(user:, reason: nil)
        return { success: false, error: 'User not found' } unless user

        # Update user status (you might want to add an active field to users table)
        # For now, we'll just update a flag in preferences
        current_preferences = user.preferences || {}
        current_preferences['account_status'] = 'deactivated'
        current_preferences['deactivation_reason'] = reason
        current_preferences['deactivated_at'] = Time.current.iso8601

        if user.update(preferences: current_preferences)
          # Create notification
          Notification.create!(
            user: user,
            notification_type: 'account_deactivated',
            title: 'Account Deactivated',
            message: 'Your account has been deactivated. Contact support if this was done in error.',
            metadata: {
              reason: reason,
              deactivated_at: Time.current.iso8601
            }
          )

          {
            success: true,
            message: 'Account deactivated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to deactivate account',
            details: user.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Account deactivation error: #{e.message}"
        {
          success: false,
          error: 'Failed to deactivate account',
          details: e.message
        }
      end

      private

      # Generate profile data hash
      # @param user [User] User to generate data for
      # @return [Hash] Profile data
      def profile_data(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          full_name: user.full_name,
          display_name: user.display_name,
          phone: user.phone,
          date_of_birth: user.date_of_birth,
          age: user.age,
          gender: user.gender,
          bio: user.bio,
          avatar: user.avatar,
          avatar_url: user.avatar.present? ? "/uploads/avatars/#{user.avatar}" : nil,
          role: user.role,
          profile_complete: user.profile_complete?,
          profile_completion_percentage: user.profile_completion_percentage,
          preferences: user.preferences,
          notification_preferences: user.notification_preferences,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end
    end
  end
end
