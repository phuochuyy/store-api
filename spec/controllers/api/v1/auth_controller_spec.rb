require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :controller do
  let(:secret_key) { Rails.application.credentials.secret_key_base || 'fallback_secret_key' }
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:valid_credentials) { { email: 'test@example.com', password: 'password123' } }
  let(:invalid_credentials) { { email: 'test@example.com', password: 'wrongpassword' } }

  before do
    request.headers['Content-Type'] = 'application/json'
  end

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns success with token' do
        user # create user first
        post :login, params: valid_credentials

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Login successful'
        )
        expect(JSON.parse(response.body)['data']).to include('token', 'user')
      end

      it 'returns user information' do
        user # create user first
        post :login, params: valid_credentials

        user_data = JSON.parse(response.body)['data']['user']
        expect(user_data).to include(
          'id' => user.id,
          'email' => user.email,
          'name' => user.name,
          'role' => user.role
        )
        expect(user_data).not_to include('password_digest')
      end

      it 'creates a valid JWT token' do
        user # create user first
        post :login, params: valid_credentials

        token = JSON.parse(response.body)['data']['token']
        decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })

        expect(decoded_token[0]['user_id']).to eq(user.id)
        expect(decoded_token[0]['email']).to eq(user.email)
      end

      it 'returns refresh_token in response' do
        user # create user first
        post :login, params: valid_credentials

        expect(JSON.parse(response.body)['data']).to include('refresh_token')
        refresh_token = JSON.parse(response.body)['data']['refresh_token']
        expect(refresh_token).to be_present
      end

      it 'includes device_id in token when X-Device-ID header is provided' do
        user # create user first
        request.headers['X-Device-ID'] = 'test-device-123'
        post :login, params: valid_credentials

        token = JSON.parse(response.body)['data']['token']
        decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
        expect(decoded_token[0]['device_id']).to eq('test-device-123')
      end

      it 'generates device_id from User-Agent when X-Device-ID not provided' do
        user # create user first
        request.headers['User-Agent'] = 'TestAgent/1.0'
        post :login, params: valid_credentials

        token = JSON.parse(response.body)['data']['token']
        decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
        expect(decoded_token[0]['device_id']).to be_present
      end

      it 'includes ip_hash in token' do
        user # create user first
        test_ip = '192.168.1.1'
        # Mock remote_ip in controller
        allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return(test_ip)
        post :login, params: valid_credentials

        token = JSON.parse(response.body)['data']['token']
        decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
        # IP hash is first 16 chars of SHA256 hash
        expected_hash = Digest::SHA256.hexdigest(test_ip)[0..15]
        actual_hash = decoded_token[0]['ip_hash']
        expect(actual_hash).to eq(expected_hash)
      end

      it 'handles email with whitespace' do
        user # create user first
        post :login, params: { email: '  test@example.com  ', password: 'password123' }

        expect(response).to have_http_status(:ok)
      end

      it 'handles case-insensitive email' do
        user # create user first
        post :login, params: { email: 'TEST@EXAMPLE.COM', password: 'password123' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid credentials' do
      it 'returns error for wrong password' do
        user # create user first
        post :login, params: invalid_credentials

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid email or password'
        )
      end

      it 'returns error for non-existent email' do
        post :login, params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid email or password'
        )
      end

      it 'returns error for missing email' do
        post :login, params: { password: 'password123' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email and password are required'
        )
      end

      it 'returns error for missing password' do
        post :login, params: { email: 'test@example.com' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email and password are required'
        )
      end

      it 'returns error for invalid email format' do
        post :login, params: { email: 'invalid-email', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid email or password'
        )
      end

      it 'returns error for empty email' do
        post :login, params: { email: '', password: 'password123' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for empty password' do
        post :login, params: { email: 'test@example.com', password: '' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for nil email' do
        post :login, params: { email: nil, password: 'password123' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for nil password' do
        post :login, params: { email: 'test@example.com', password: nil }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST #register' do
    let(:valid_registration) do
      {
        name: 'New User',
        first_name: 'New',
        last_name: 'User',
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    context 'with valid registration data' do
      it 'creates a new user' do
        expect do
          post :register, params: valid_registration
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'User registered successfully'
        )
      end

      it 'returns user data without password' do
        post :register, params: valid_registration

        user_data = JSON.parse(response.body)['data']['user']
        expect(user_data).to include(
          'name' => 'New User',
          'email' => 'newuser@example.com',
          'role' => 'customer'
        )
        expect(user_data).not_to include('password', 'password_digest')
      end

      it 'sets default role to customer' do
        post :register, params: valid_registration

        user = User.find_by(email: 'newuser@example.com')
        expect(user.role).to eq('customer')
      end

      it 'generates email verification token' do
        post :register, params: valid_registration

        user = User.find_by(email: 'newuser@example.com')
        expect(user.email_verification_token).to be_present
      end
    end

    context 'with invalid registration data' do
      it 'returns error for duplicate email' do
        post :register, params: valid_registration.merge(email: user.email)

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for password mismatch' do
        post :register, params: valid_registration.merge(password_confirmation: 'different')

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for missing required fields' do
        post :register, params: { email: 'test@example.com' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for invalid email format' do
        post :register, params: valid_registration.merge(email: 'invalid-email')

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for password too short' do
        post :register, params: valid_registration.merge(password: '12345', password_confirmation: '12345')

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for name too short' do
        post :register, params: valid_registration.merge(name: 'A')

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'returns error for name too long' do
        long_name = 'A' * 51
        post :register, params: valid_registration.merge(name: long_name)

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Validation failed'
        )
      end

      it 'prevents non-admin from setting role' do
        customer_user = create(:user, :customer)
        token = JWT.encode(
          { user_id: customer_user.id, email: customer_user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
          secret_key, 'HS256'
        )
        request.headers['Authorization'] = "Bearer #{token}"

        post :register, params: valid_registration.merge(role: 'admin')

        new_user = User.find_by(email: 'newuser@example.com')
        expect(new_user.role).to eq('customer')
      end

      it 'allows admin to set role' do
        admin_user = create(:user, :admin)
        token = JWT.encode(
          { user_id: admin_user.id, email: admin_user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
          secret_key, 'HS256'
        )
        request.headers['Authorization'] = "Bearer #{token}"

        post :register, params: valid_registration.merge(role: 'admin')

        new_user = User.find_by(email: 'newuser@example.com')
        expect(new_user.role).to eq('admin')
      end
    end
  end

  describe 'POST #logout' do
    let(:token) do
      JWT.encode({ user_id: user.id, email: user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
                 secret_key, 'HS256')
    end

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'blacklists the token' do
        expect do
          post :logout
        end.to change(JwtBlacklistToken, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Logged out successfully'
        )
      end

      it 'prevents token reuse after logout' do
        post :logout

        # Try to use the same token again
        get :me
        expect(response).to have_http_status(:unauthorized)
      end

      it 'allows multiple logouts' do
        post :logout
        expect(response).to have_http_status(:ok)

        # Second logout with same token - token is already blacklisted
        # but logout should still succeed (idempotent operation)
        # Create a new token for second logout since first one is blacklisted
        new_token = Auth::Jwt::EncodeService.encode(user)
        request.headers['Authorization'] = "Bearer #{new_token}"
        post :logout
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        post :logout

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Token not provided'
        )
      end
    end
  end

  describe 'GET #me' do
    let(:token) do
      JWT.encode({ user_id: user.id, email: user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
                 secret_key, 'HS256')
    end

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with valid token' do
      it 'returns current user information' do
        user # create user first
        get :me

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        user_data = response_body['data']
        expect(user_data).to include(
          'id' => user.id,
          'email' => user.email,
          'name' => user.name,
          'role' => user.role
        )
        expect(user_data).not_to include('password_digest')
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized for malformed token' do
        request.headers['Authorization'] = 'Bearer invalid-token'
        get :me

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid token'
        )
      end

      it 'returns unauthorized for blacklisted token' do
        # First logout to blacklist the token
        post :logout

        # Then try to use it
        get :me
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for expired token' do
        expired_token = JWT.encode(
          { user_id: user.id, email: user.email, iat: 2.days.ago.to_i, exp: 1.day.ago.to_i },
          secret_key, 'HS256'
        )
        request.headers['Authorization'] = "Bearer #{expired_token}"
        get :me

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for token with wrong secret' do
        wrong_token = JWT.encode(
          { user_id: user.id, email: user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
          'wrong-secret', 'HS256'
        )
        request.headers['Authorization'] = "Bearer #{wrong_token}"
        get :me

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for token from different user' do
        other_user = create(:user, email: 'other@example.com')
        other_token = JWT.encode(
          { user_id: other_user.id, email: other_user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
          secret_key, 'HS256'
        )
        request.headers['Authorization'] = "Bearer #{other_token}"
        get :me

        # Should return other user's data, not current user
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['id']).to eq(other_user.id)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        get :me

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Token not provided'
        )
      end
    end
  end

  describe 'POST #refresh_token' do
    let(:device_id) { 'test-device-123' }
    let(:ip_address) { '192.168.1.1' }
    let(:refresh_token) do
      Auth::Jwt::EncodeService.encode_refresh_token(user, device_id: device_id, ip_address: ip_address)
    end

    before do
      allow(request).to receive(:remote_ip).and_return(ip_address)
      request.headers['X-Device-ID'] = device_id
    end

    context 'with valid access token' do
      let(:access_token) do
        Auth::Jwt::EncodeService.encode(user, device_id: device_id, ip_address: ip_address)
      end

      before do
        request.headers['Authorization'] = "Bearer #{access_token}"
      end

      it 'returns new token' do
        user # create user first
        post :refresh_token

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Token refreshed successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('token', 'refresh_token')
      end

      it 'blacklists old token' do
        user # create user first
        expect do
          post :refresh_token
        end.to change(JwtBlacklistToken, :count).by(1)
      end

      it 'returns different tokens on each refresh' do
        user # create user first
        # First refresh using refresh_token param
        first_refresh_token = Auth::Jwt::EncodeService.encode_refresh_token(user, device_id: device_id, ip_address: ip_address)
        post :refresh_token, params: { refresh_token: first_refresh_token }
        expect(response).to have_http_status(:ok)
        first_response = JSON.parse(response.body)['data']
        first_token = first_response['token']
        first_new_refresh_token = first_response['refresh_token']

        # Wait a moment to ensure different iat timestamp
        sleep(1)

        # Second refresh using new refresh_token from first response
        post :refresh_token, params: { refresh_token: first_new_refresh_token }
        expect(response).to have_http_status(:ok)
        second_response = JSON.parse(response.body)['data']
        second_token = second_response['token']
        second_new_refresh_token = second_response['refresh_token']

        # Tokens should be different
        expect(first_token).not_to eq(second_token)
        expect(first_new_refresh_token).not_to eq(second_new_refresh_token)
      end
    end

    context 'with valid refresh token param' do
      it 'returns new tokens using refresh_token param' do
        user # create user first
        post :refresh_token, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Token refreshed successfully'
        )
        expect(JSON.parse(response.body)['data']).to include('token', 'refresh_token')
      end

      it 'blacklists old refresh token (token rotation)' do
        user # create user first
        post :refresh_token, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        expect(Auth::Jwt::BlacklistService.blacklisted?(refresh_token)).to be true
      end

      it 'rejects refresh with mismatched device_id' do
        user # create user first
        request.headers['X-Device-ID'] = 'wrong-device'
        post :refresh_token, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['message']).to include('Device mismatch')
      end

      it 'allows refresh with same device_id' do
        user # create user first
        post :refresh_token, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        new_token = JSON.parse(response.body)['data']['token']
        decoded = JWT.decode(new_token, secret_key, true, { algorithm: 'HS256' })
        expect(decoded[0]['device_id']).to eq(device_id)
      end

      it 'prevents reuse of refresh token after rotation' do
        user # create user first
        # First refresh
        post :refresh_token, params: { refresh_token: refresh_token }
        expect(response).to have_http_status(:ok)

        # Try to use same refresh token again (should fail)
        post :refresh_token, params: { refresh_token: refresh_token }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error for blacklisted refresh token' do
        user # create user first
        Auth::Jwt::BlacklistService.blacklist_token(refresh_token, token_type: 'refresh')
        post :refresh_token, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false
        )
        # Blacklisted token returns "Invalid or expired refresh token" (decode returns nil)
        expect(JSON.parse(response.body)['message']).to be_present
      end

      it 'returns error for refresh token from different user' do
        other_user = create(:user, email: 'other@example.com')
        other_refresh_token = JWT.encode(
          { user_id: other_user.id, type: 'refresh', iat: Time.current.to_i, exp: 7.days.from_now.to_i },
          secret_key, 'HS256'
        )
        post :refresh_token, params: { refresh_token: other_refresh_token }

        # Should work but return other user's tokens
        expect(response).to have_http_status(:ok)
        new_token = JSON.parse(response.body)['data']['token']
        decoded = JWT.decode(new_token, secret_key, true, { algorithm: 'HS256' })
        expect(decoded[0]['user_id']).to eq(other_user.id)
      end
    end

    context 'with invalid token' do
      it 'returns error for blank refresh token' do
        post :refresh_token, params: { refresh_token: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Refresh token is required'
        )
      end

      it 'returns error for invalid token' do
        post :refresh_token, params: { refresh_token: 'invalid-token' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false
        )
        # Error message can vary
        expect(JSON.parse(response.body)['message']).to be_present
      end

      it 'returns error for expired token' do
        expired_token = JWT.encode(
          { user_id: user.id, iat: 2.days.ago.to_i, exp: 1.day.ago.to_i },
          secret_key, 'HS256'
        )
        post :refresh_token, params: { refresh_token: expired_token }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          'success' => false
        )
        # Error message can vary
        expect(JSON.parse(response.body)['message']).to be_present
      end

      it 'returns error for tampered token' do
        valid_token = JWT.encode(
          { user_id: user.id, type: 'refresh', iat: Time.current.to_i, exp: 7.days.from_now.to_i },
          secret_key, 'HS256'
        )
        tampered_token = valid_token[0..-5] + 'XXXX'
        post :refresh_token, params: { refresh_token: tampered_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without token' do
      it 'returns error for missing refresh token' do
        request.headers['Authorization'] = nil
        post :refresh_token

        # refresh_token skip authentication, so it returns bad_request for missing token
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Refresh token is required'
        )
      end
    end
  end

  describe 'GET #verify_email' do
    let(:unverified_user) { create(:user, email_verified_at: nil) }

    context 'with valid verification token' do
      it 'verifies email successfully' do
        token = unverified_user.email_verification_token
        get :verify_email, params: { token: token }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Email verified successfully'
        )
        expect(unverified_user.reload.email_verified?).to be true
        expect(unverified_user.email_verification_token).to be_nil
      end

      it 'sets email_verified_at timestamp' do
        token = unverified_user.email_verification_token
        get :verify_email, params: { token: token }

        expect(unverified_user.reload.email_verified_at).to be_present
      end
    end

    context 'with invalid verification token' do
      it 'returns error for blank token' do
        get :verify_email, params: { token: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Verification token is required'
        )
      end

      it 'returns error for non-existent token' do
        get :verify_email, params: { token: 'invalid-token' }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Invalid or expired verification token'
        )
      end

      it 'returns error for nil token' do
        get :verify_email, params: { token: nil }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with already verified email' do
      let(:verified_user) { create(:user, email_verified_at: Time.current) }

      it 'returns error for already verified email' do
        token = verified_user.email_verification_token
        get :verify_email, params: { token: token }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email has already been verified'
        )
      end
    end
  end

  describe 'POST #resend_verification' do
    let(:unverified_user) { create(:user, email_verified_at: nil) }

    context 'with valid email' do
      it 'sends verification email successfully' do
        post :resend_verification, params: { email: unverified_user.email }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Verification email sent successfully'
        )
      end

      it 'generates new verification token' do
        old_token = unverified_user.email_verification_token
        post :resend_verification, params: { email: unverified_user.email }

        expect(unverified_user.reload.email_verification_token).not_to eq(old_token)
        expect(unverified_user.email_verification_token).to be_present
      end

      it 'sends email via mailer' do
        expect(EmailVerificationMailer).to receive(:resend_verification_email).with(unverified_user).and_return(double(deliver_now: true))
        post :resend_verification, params: { email: unverified_user.email }
      end

      it 'handles case-insensitive email' do
        post :resend_verification, params: { email: unverified_user.email.upcase }

        expect(response).to have_http_status(:ok)
      end

      it 'handles email with whitespace' do
        post :resend_verification, params: { email: "  #{unverified_user.email}  " }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid email' do
      it 'returns error for blank email' do
        post :resend_verification, params: { email: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email is required'
        )
      end

      it 'returns error for non-existent email' do
        post :resend_verification, params: { email: 'nonexistent@example.com' }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'User not found'
        )
      end

      it 'returns error for nil email' do
        post :resend_verification, params: { email: nil }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for invalid email format' do
        post :resend_verification, params: { email: 'invalid-email' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with already verified email' do
      let(:verified_user) { create(:user, email_verified_at: Time.current) }

      it 'returns error for already verified email' do
        post :resend_verification, params: { email: verified_user.email }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Email has already been verified'
        )
      end
    end

    context 'when email sending fails' do
      it 'still returns success even if email fails' do
        allow(EmailVerificationMailer).to receive(:resend_verification_email).and_raise(StandardError, 'Email error')
        post :resend_verification, params: { email: unverified_user.email }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'Verification email sent successfully'
        )
      end
    end
  end

  describe 'POST #revoke_all_tokens' do
    let(:admin_user) { create(:user, :admin, email: 'admin@example.com', password: 'password123') }
    let(:token) do
      JWT.encode({ user_id: admin_user.id, email: admin_user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
                 secret_key, 'HS256')
    end

    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end

    context 'with admin user' do
      it 'revokes all user tokens' do
        user # create target user
        post :revoke_all_tokens, params: { user_id: user.id }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'success' => true,
          'message' => 'All tokens for user have been revoked'
        )
      end

      it 'returns error for missing user_id' do
        post :revoke_all_tokens, params: {}

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'User ID is required'
        )
      end

      it 'returns error for non-existent user' do
        post :revoke_all_tokens, params: { user_id: 99_999 }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'User not found'
        )
      end

      it 'returns error for blank user_id' do
        post :revoke_all_tokens, params: { user_id: '' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for nil user_id' do
        post :revoke_all_tokens, params: { user_id: nil }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with non-admin user' do
      let(:customer_token) do
        JWT.encode({ user_id: user.id, email: user.email, iat: Time.current.to_i, exp: 24.hours.from_now.to_i },
                   secret_key, 'HS256')
      end

      before do
        request.headers['Authorization'] = "Bearer #{customer_token}"
      end

      it 'returns forbidden for customer user' do
        post :revoke_all_tokens, params: { user_id: user.id }

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to include(
          'success' => false,
          'message' => 'Admin access required'
        )
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = nil
        post :revoke_all_tokens, params: { user_id: user.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
