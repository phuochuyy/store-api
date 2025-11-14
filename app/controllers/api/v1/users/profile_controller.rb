# frozen_string_literal: true

module Api
  module V1
    module Users
      class ProfileController < Api::V1::BaseController
        before_action :authenticate_user!

        def show
          result = Users::ProfileService.get_profile(current_user)

          if result[:success]
            render_success(result[:profile], 'Profile retrieved successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        def update
          result = Users::ProfileUpdateService.update_profile(user: current_user, **profile_params[:profile] || {})

          if result[:success]
            render_success(result[:profile], 'Profile updated successfully')
          else
            render_error(result[:error], :unprocessable_content, result[:errors] || result[:details])
          end
        end

        def upload_avatar
          result = Users::ProfileAvatarService.upload_avatar(user: current_user, avatar_file: params[:avatar])

          if result[:success]
            profile_data = Users::ProfileDataService.profile_data(current_user.reload)
            render_success({ profile: profile_data }, 'Avatar uploaded successfully')
          else
            render_error(result[:error], :unprocessable_content, result[:details])
          end
        end

        def remove_avatar
          result = Users::ProfileAvatarService.delete_avatar(current_user)

          if result[:success]
            profile_data = Users::ProfileDataService.profile_data(current_user.reload)
            render_success({ profile: profile_data }, 'Avatar removed successfully')
          else
            render_error(result[:error], :unprocessable_content, result[:details])
          end
        end

        private

        def profile_params
          params.expect(profile: %i[first_name last_name name phone gender bio])
        end
      end
    end
  end
end

