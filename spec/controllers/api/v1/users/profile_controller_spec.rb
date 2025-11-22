# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::Users::ProfileController, type: :controller do
  let(:user) { create(:user) }

  # Helper method to generate JWT token
  def generate_token(user)
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, secret_key, 'HS256')
  end

  let(:user_token) { generate_token(user) }

  before do
    request.headers['Content-Type'] = 'application/json'
    request.headers['Authorization'] = "Bearer #{user_token}"
  end

  describe 'GET #show' do
    it 'returns user profile' do
      allow(Users::ProfileService).to receive(:get_profile).and_return({
                                                                         success: true,
                                                                         profile: {
                                                                           id: user.id,
                                                                           name: user.name,
                                                                           email: user.email
                                                                         }
                                                                       })

      get :show

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_present
    end
  end

  describe 'PATCH #update' do
    let(:valid_profile_params) do
      {
        profile: {
          first_name: 'John',
          last_name: 'Doe',
          phone: '1234567890'
        }
      }
    end

    it 'updates profile successfully' do
      allow(Users::ProfileUpdateService).to receive(:update_profile).and_return({
                                                                                  success: true,
                                                                                  profile: {
                                                                                    id: user.id,
                                                                                    first_name: 'John',
                                                                                    last_name: 'Doe'
                                                                                  }
                                                                                })

      patch :update, params: valid_profile_params

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Profile updated successfully')
    end

    it 'returns error when update fails' do
      allow(Users::ProfileUpdateService).to receive(:update_profile).and_return({
                                                                                  success: false,
                                                                                  error: 'Update failed',
                                                                                  errors: ['Phone is invalid']
                                                                                })

      patch :update, params: valid_profile_params

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end

  describe 'POST #upload_avatar' do
    it 'uploads avatar successfully' do
      allow(Users::ProfileAvatarService).to receive(:upload_avatar).and_return({
                                                                                 success: true
                                                                               })
      allow(Users::ProfileDataService).to receive(:profile_data).and_return({
                                                                              id: user.id,
                                                                              avatar_url: 'http://example.com/avatar.jpg'
                                                                            })

      post :upload_avatar, params: {
        avatar: fixture_file_upload('test.jpg', 'image/jpeg')
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Avatar uploaded successfully')
    end

    it 'returns error when upload fails' do
      allow(Users::ProfileAvatarService).to receive(:upload_avatar).and_return({
                                                                                 success: false,
                                                                                 error: 'Upload failed',
                                                                                 details: 'File too large'
                                                                               })

      post :upload_avatar, params: {
        avatar: fixture_file_upload('test.jpg', 'image/jpeg')
      }

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end

  describe 'DELETE #remove_avatar' do
    it 'removes avatar successfully' do
      allow(Users::ProfileAvatarService).to receive(:delete_avatar).and_return({
                                                                                 success: true
                                                                               })
      allow(Users::ProfileDataService).to receive(:profile_data).and_return({
                                                                              id: user.id,
                                                                              avatar_url: nil
                                                                            })

      delete :remove_avatar

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Avatar removed successfully')
    end

    it 'returns error when removal fails' do
      allow(Users::ProfileAvatarService).to receive(:delete_avatar).and_return({
                                                                                 success: false,
                                                                                 error: 'Removal failed'
                                                                               })

      delete :remove_avatar

      expect(response).to have_http_status(:unprocessable_content)
      json_response = response.parsed_body
      expect(json_response['success']).to be false
    end
  end
end
# rubocop:enable Metrics/BlockLength
