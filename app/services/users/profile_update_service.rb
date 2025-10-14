# frozen_string_literal: true

module Users
  class ProfileUpdateService
    class << self
      # Update user profile
      # @param user [User] User to update
      # @param profile_params [Hash] Profile parameters
      # @return [Hash] Result with success status
      def update_profile(user:, **profile_params)
        return { success: false, error: 'User not found' } unless user

        allowed_params = filter_allowed_params(profile_params)
        validation_result = validate_profile_params(allowed_params)
        return validation_result unless validation_result[:success]

        update_result = perform_profile_update(user, allowed_params)
        build_update_response(user, update_result)
      rescue StandardError => e
        Rails.logger.error "Profile update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update profile',
          details: e.message
        }
      end

      private

      def filter_allowed_params(profile_params)
        profile_params.slice(
          :first_name, :last_name, :phone, :date_of_birth,
          :gender, :bio, :avatar
        )
      end

      def validate_profile_params(params)
        return { success: true } if params[:date_of_birth].blank?

        date_validation = validate_date_of_birth(params[:date_of_birth])
        return date_validation unless date_validation[:success]

        { success: true }
      end

      def validate_date_of_birth(date_of_birth)
        parsed_date = Date.parse(date_of_birth.to_s)

        return { success: false, error: 'Date of birth cannot be in the future' } if parsed_date > Date.current

        return { success: false, error: 'You must be at least 13 years old' } if parsed_date > 13.years.ago.to_date

        { success: true, parsed_date: parsed_date }
      rescue ArgumentError
        { success: false, error: 'Invalid date format' }
      end

      def perform_profile_update(user, params)
        user.update(params)
      end

      def build_update_response(user, success)
        if success
          {
            success: true,
            profile: ProfileDataService.profile_data(user),
            message: 'Profile updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update profile',
            details: user.errors.full_messages
          }
        end
      end
    end
  end
end
