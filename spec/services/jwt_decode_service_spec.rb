require 'rails_helper'

RSpec.describe JwtDecodeService, type: :service do
  let(:user) { create(:user, email: 'test@example.com') }

  describe '.decode' do
    context 'with valid token' do
      it 'decodes a valid JWT token' do
        token = JwtEncodeService.encode(user)
        decoded = JwtDecodeService.decode(token)

        expect(decoded).to be_present
        expect(decoded['user_id']).to eq(user.id)
        expect(decoded['email']).to eq(user.email)
      end
    end

    context 'with invalid token' do
      it 'returns nil for blank token' do
        result = JwtDecodeService.decode('')
        expect(result).to be_nil
      end

      it 'returns nil for nil token' do
        result = JwtDecodeService.decode(nil)
        expect(result).to be_nil
      end

      it 'returns nil for malformed token' do
        result = JwtDecodeService.decode('invalid.token')
        expect(result).to be_nil
      end

      it 'returns nil for expired token' do
        expired_token = JwtEncodeService.encode(user, expiry: -1.hour)
        result = JwtDecodeService.decode(expired_token)
        expect(result).to be_nil
      end

      it 'returns nil for token with wrong signature' do
        # Create a token with different secret
        payload = { user_id: user.id, email: user.email }
        wrong_token = JWT.encode(payload, 'wrong_secret', 'HS256')
        result = JwtDecodeService.decode(wrong_token)
        expect(result).to be_nil
      end
    end
  end

  describe '.decode_user' do
    context 'with valid token' do
      it 'returns user for valid token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.decode_user(token)

        expect(result).to eq(user)
      end
    end

    context 'with invalid token' do
      it 'returns nil for invalid token' do
        result = JwtDecodeService.decode_user('invalid_token')
        expect(result).to be_nil
      end

      it 'returns nil for non-existent user' do
        # Create token for non-existent user
        payload = { user_id: 99_999, email: 'nonexistent@example.com' }
        token = JWT.encode(payload, JwtEncodeService::SECRET_KEY, 'HS256')
        result = JwtDecodeService.decode_user(token)
        expect(result).to be_nil
      end
    end
  end

  describe '.decode_refresh_token' do
    context 'with valid refresh token' do
      it 'returns payload for valid refresh token' do
        token = JwtEncodeService.encode_refresh_token(user)
        result = JwtDecodeService.decode_refresh_token(token)

        expect(result).to be_present
        expect(result['type']).to eq('refresh')
        expect(result['user_id']).to eq(user.id)
      end
    end

    context 'with invalid refresh token' do
      it 'returns nil for regular token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.decode_refresh_token(token)
        expect(result).to be_nil
      end

      it 'returns nil for invalid token' do
        result = JwtDecodeService.decode_refresh_token('invalid_token')
        expect(result).to be_nil
      end
    end
  end

  describe '.decode_password_reset_token' do
    context 'with valid password reset token' do
      it 'returns payload for valid password reset token' do
        token = JwtEncodeService.encode_password_reset_token(user)
        result = JwtDecodeService.decode_password_reset_token(token)

        expect(result).to be_present
        expect(result['type']).to eq('password_reset')
        expect(result['user_id']).to eq(user.id)
      end
    end

    context 'with invalid password reset token' do
      it 'returns nil for regular token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.decode_password_reset_token(token)
        expect(result).to be_nil
      end

      it 'returns nil for invalid token' do
        result = JwtDecodeService.decode_password_reset_token('invalid_token')
        expect(result).to be_nil
      end
    end
  end

  describe '.decode_email_verification_token' do
    context 'with valid email verification token' do
      it 'returns payload for valid email verification token' do
        token = JwtEncodeService.encode_email_verification_token(user)
        result = JwtDecodeService.decode_email_verification_token(token)

        expect(result).to be_present
        expect(result['type']).to eq('email_verification')
        expect(result['user_id']).to eq(user.id)
        expect(result['email']).to eq(user.email)
      end
    end

    context 'with invalid email verification token' do
      it 'returns nil for regular token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.decode_email_verification_token(token)
        expect(result).to be_nil
      end

      it 'returns nil for invalid token' do
        result = JwtDecodeService.decode_email_verification_token('invalid_token')
        expect(result).to be_nil
      end
    end
  end

  describe '.expired?' do
    context 'with valid token' do
      it 'returns false for non-expired token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.expired?(token)
        expect(result).to be false
      end
    end

    context 'with expired token' do
      it 'returns true for expired token' do
        expired_token = JwtEncodeService.encode(user, expiry: -1.hour)
        result = JwtDecodeService.expired?(expired_token)
        expect(result).to be true
      end
    end

    context 'with invalid token' do
      it 'returns true for invalid token' do
        result = JwtDecodeService.expired?('invalid_token')
        expect(result).to be true
      end

      it 'returns true for blank token' do
        result = JwtDecodeService.expired?('')
        expect(result).to be true
      end
    end
  end

  describe '.expiry_time' do
    context 'with valid token' do
      it 'returns expiry time for valid token' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.expiry_time(token)

        expect(result).to be_present
        expect(result).to be_a(Time)
        expect(result).to be > Time.current
      end
    end

    context 'with invalid token' do
      it 'returns nil for invalid token' do
        result = JwtDecodeService.expiry_time('invalid_token')
        expect(result).to be_nil
      end
    end
  end

  describe '.time_until_expiry' do
    context 'with valid token' do
      it 'returns time until expiry' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.time_until_expiry(token)

        expect(result).to be_present
        expect(result).to be > 0
        expect(result).to be < 24.hours
      end
    end

    context 'with invalid token' do
      it 'returns nil for invalid token' do
        result = JwtDecodeService.time_until_expiry('invalid_token')
        expect(result).to be_nil
      end
    end
  end

  describe '.validate_token' do
    context 'with valid token' do
      it 'returns validation success' do
        token = JwtEncodeService.encode(user)
        result = JwtDecodeService.validate_token(token)

        expect(result[:valid]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:payload]).to be_present
        expect(result[:error]).to be_nil
      end
    end

    context 'with invalid token' do
      it 'returns validation failure for blank token' do
        result = JwtDecodeService.validate_token('')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('Token is blank')
      end

      it 'returns validation failure for malformed token' do
        result = JwtDecodeService.validate_token('invalid.token')
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('Invalid token format')
      end

      it 'returns validation failure for expired token' do
        # Create a token that expires in the past
        payload = {
          user_id: user.id,
          email: user.email,
          iat: Time.current.to_i,
          exp: 1.hour.ago.to_i
        }
        expired_token = JWT.encode(payload, JwtEncodeService::SECRET_KEY, 'HS256')
        result = JwtDecodeService.validate_token(expired_token)
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('Invalid token format')
      end

      it 'returns validation failure for non-existent user' do
        payload = {
          user_id: 99_999,
          email: 'nonexistent@example.com',
          iat: Time.current.to_i,
          exp: 1.hour.from_now.to_i
        }
        token = JWT.encode(payload, JwtEncodeService::SECRET_KEY, 'HS256')
        result = JwtDecodeService.validate_token(token)
        expect(result[:valid]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end
  end
end
