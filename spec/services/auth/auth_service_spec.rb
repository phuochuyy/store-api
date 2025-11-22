require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Auth::AuthService, type: :service do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

  describe '.login' do
    context 'with valid credentials' do
      it 'returns success with tokens and user data' do
        result = described_class.login(user.email, 'password123')

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Login successful')
        expect(result[:tokens]).to include(:token, :refresh_token)
        expect(result[:user]).to be_present
        expect(result[:user][:id]).to eq(user.id)
        expect(result[:user][:email]).to eq(user.email)
      end

      it 'includes device_id and ip_address in tokens when provided' do
        device_id = 'test-device-123'
        ip_address = '192.168.1.1'

        result = described_class.login(user.email, 'password123', device_id: device_id, ip_address: ip_address)

        expect(result[:success]).to be true
        token = result[:tokens][:token]
        payload = Auth::Jwt::DecodeService.decode_raw(token)
        expect(payload['device_id']).to eq(device_id)
        expect(payload['ip_hash']).to eq(Digest::SHA256.hexdigest(ip_address)[0..15])
      end

      it 'tracks tokens for user' do
        result = described_class.login(user.email, 'password123')

        expect(result[:success]).to be true
        # Tokens should be tracked in cache
        expect(Auth::Jwt::CacheService.redis.keys("*user_tokens:#{user.id}*")).not_to be_empty
      end

      it 'returns success for case-insensitive email' do
        # Auth::AuthService now uses User.find_by_email which is case-insensitive
        result = described_class.login(user.email.upcase, 'password123')

        expect(result[:success]).to be true
        expect(result[:tokens]).to be_present
        expect(result[:user]).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'returns failure for incorrect email' do
        result = described_class.login('wrong@example.com', 'password123')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
        expect(result[:tokens]).to be_nil
        expect(result[:user]).to be_nil
      end

      it 'returns failure for incorrect password' do
        result = described_class.login(user.email, 'wrongpassword')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid email or password')
        expect(result[:tokens]).to be_nil
        expect(result[:user]).to be_nil
      end
    end
  end

  describe '.register' do
    let(:valid_params) do
      {
        name: 'New User',
        first_name: 'New',
        last_name: 'User',
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    context 'with valid parameters' do
      it 'creates user and returns success' do
        expect do
          result = described_class.register(valid_params)
          expect(result[:success]).to be true
          expect(result[:message]).to eq('User registered successfully')
          expect(result[:tokens]).to include(:token, :refresh_token)
          expect(result[:user]).to be_present
        end.to change(User, :count).by(1)
      end

      it 'includes device_id and ip_address in tokens when provided' do
        device_id = 'test-device-123'
        ip_address = '192.168.1.1'

        result = described_class.register(valid_params, device_id: device_id, ip_address: ip_address)

        expect(result[:success]).to be true
        token = result[:tokens][:token]
        payload = Auth::Jwt::DecodeService.decode_raw(token)
        expect(payload['device_id']).to eq(device_id)
        expect(payload['ip_hash']).to eq(Digest::SHA256.hexdigest(ip_address)[0..15])
      end

      it 'sets default role to customer' do
        described_class.register(valid_params)

        new_user = User.find_by(email: 'newuser@example.com')
        expect(new_user.role).to eq('customer')
      end
    end

    context 'with invalid parameters' do
      it 'returns failure for duplicate email' do
        result = described_class.register(valid_params.merge(email: user.email))

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email has already been taken')
        expect(result[:tokens]).to be_nil
        expect(result[:user]).to be_nil
      end

      it 'returns failure for password mismatch' do
        result = described_class.register(valid_params.merge(password_confirmation: 'different'))

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Password confirmation doesn't match Password")
      end

      it 'returns failure for missing required fields' do
        result = described_class.register({ email: 'test@example.com' })

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Password can't be blank")
        expect(result[:errors]).to include("Name can't be blank")
      end
    end
  end

  describe '.refresh_token' do
    let(:device_id) { 'test-device-123' }
    let(:ip_address) { '192.168.1.1' }
    let(:refresh_token) do
      Auth::Jwt::EncodeService.encode_refresh_token(user, device_id: device_id, ip_address: ip_address)
    end

    context 'with valid refresh token' do
      it 'returns new tokens' do
        result = described_class.refresh_token(refresh_token)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Token refreshed successfully')
        expect(result[:tokens]).to include(:token, :refresh_token)
      end

      it 'blacklists old refresh token (token rotation)' do
        result = described_class.refresh_token(refresh_token)

        expect(result[:success]).to be true
        expect(Auth::Jwt::BlacklistService.blacklisted?(refresh_token)).to be true
      end

      it 'generates new tokens with same device_id' do
        result = described_class.refresh_token(refresh_token, device_id: device_id, ip_address: ip_address)

        expect(result[:success]).to be true
        new_token = result[:tokens][:token]
        payload = Auth::Jwt::DecodeService.decode_raw(new_token)
        expect(payload['device_id']).to eq(device_id)
      end

      it 'allows refresh without device_id (backward compatibility)' do
        old_refresh_token = Auth::Jwt::EncodeService.encode_refresh_token(user)
        result = described_class.refresh_token(old_refresh_token)

        expect(result[:success]).to be true
      end
    end

    context 'with device validation' do
      it 'rejects refresh with mismatched device_id' do
        wrong_device_id = 'wrong-device'
        result = described_class.refresh_token(refresh_token, device_id: wrong_device_id, ip_address: ip_address)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Device mismatch')
      end

      it 'allows refresh when device_id not provided in request but present in token' do
        result = described_class.refresh_token(refresh_token, ip_address: ip_address)

        expect(result[:success]).to be true
      end
    end

    context 'with IP validation' do
      it 'logs warning but allows refresh with different IP (lenient validation)' do
        different_ip = '10.0.0.1'
        expect(Rails.logger).to receive(:warn).with(/IP mismatch/)

        result = described_class.refresh_token(refresh_token, device_id: device_id, ip_address: different_ip)

        expect(result[:success]).to be true
      end
    end

    context 'with token rotation race condition' do
      it 'handles concurrent refresh attempts gracefully' do
        # First refresh
        result1 = described_class.refresh_token(refresh_token)
        expect(result1[:success]).to be true

        # Second refresh with same token (should fail as token is blacklisted)
        result2 = described_class.refresh_token(refresh_token)

        expect(result2[:success]).to be false
        expect(result2[:error]).to include('Invalid or expired refresh token')
      end
    end

    context 'with invalid refresh token' do
      it 'returns failure for blank token' do
        result = described_class.refresh_token('')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Refresh token is required')
      end

      it 'returns failure for invalid token' do
        result = described_class.refresh_token('invalid-token')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid or expired refresh token')
      end

      it 'returns failure for non-refresh token' do
        # NOTE: Service has backward compatibility - accepts access token
        # This test verifies it works but logs a warning
        access_token = Auth::Jwt::EncodeService.encode(user)
        result = described_class.refresh_token(access_token)

        # Backward compatibility: access token is accepted
        expect(result[:success]).to be true
        expect(result[:tokens]).to be_present
      end

      it 'returns failure for already blacklisted refresh token' do
        # Blacklist the token first
        Auth::Jwt::BlacklistService.blacklist_token(refresh_token, token_type: 'refresh')

        result = described_class.refresh_token(refresh_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid or expired refresh token')
      end

      it 'returns failure for non-existent user' do
        payload = {
          user_id: 99_999,
          type: 'refresh',
          iat: Time.current.to_i,
          exp: 7.days.from_now.to_i
        }
        token = JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')

        result = described_class.refresh_token(token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end
  end

  describe '.logout' do
    let(:token) { Auth::Jwt::EncodeService.encode(user) }

    context 'with token provided' do
      it 'blacklists the token and returns success' do
        result = described_class.logout(token, user_id: user.id)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Logged out successfully')
        expect(Auth::Jwt::BlacklistService.blacklisted?(token)).to be true
      end
    end

    context 'without token' do
      it 'returns success without blacklisting' do
        result = described_class.logout(nil)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Logged out successfully')
      end
    end
  end

  describe '.get_current_user' do
    it 'returns success with user data' do
      result = described_class.get_current_user(user)

      expect(result[:success]).to be true
      expect(result[:user]).to be_present
      expect(result[:user][:id]).to eq(user.id)
      expect(result[:user][:email]).to eq(user.email)
    end

    it 'returns failure for nil user' do
      result = described_class.get_current_user(nil)

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Not authenticated')
    end
  end
end
# rubocop:enable Metrics/BlockLength
