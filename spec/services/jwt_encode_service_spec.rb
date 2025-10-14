require 'rails_helper'

RSpec.describe JwtEncodeService, type: :service do
  let(:user) { create(:user, email: 'test@example.com', role: 'admin') }

  describe '.encode' do
    it 'encodes user data into JWT token' do
      token = described_class.encode(user)

      expect(token).to be_present
      expect(token).to be_a(String)

      # Decode to verify content
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      expect(payload['user_id']).to eq(user.id)
      expect(payload['email']).to eq(user.email)
    end

    it 'includes standard JWT claims' do
      token = described_class.encode(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      expect(payload).to include('iat', 'exp')
      expect(payload['iat']).to be_present
      expect(payload['exp']).to be_present
    end

    it 'sets appropriate expiration time' do
      token = described_class.encode(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      exp_time = Time.at(payload['exp'])
      iat_time = Time.at(payload['iat'])

      # Token should expire in 24 hours
      expect(exp_time - iat_time).to be_within(60).of(24.hours.to_i)
    end

    it 'handles different user roles' do
      customer = create(:user, :customer)
      admin = create(:user, :admin)

      customer_token = described_class.encode(customer)
      admin_token = described_class.encode(admin)

      customer_payload = JWT.decode(customer_token, JwtEncodeService::SECRET_KEY, true,
                                    { algorithm: 'HS256' })[0]
      admin_payload = JWT.decode(admin_token, JwtEncodeService::SECRET_KEY, true,
                                 { algorithm: 'HS256' })[0]

      expect(customer_payload['user_id']).to eq(customer.id)
      expect(admin_payload['user_id']).to eq(admin.id)
    end
  end

  describe '.encode_refresh_token' do
    it 'encodes refresh token with correct type' do
      token = described_class.encode_refresh_token(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      expect(payload['type']).to eq('refresh')
      expect(payload['user_id']).to eq(user.id)
    end

    it 'sets longer expiration for refresh token' do
      token = described_class.encode_refresh_token(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      exp_time = Time.at(payload['exp'])
      iat_time = Time.at(payload['iat'])

      # Refresh token should expire in 7 days
      expect(exp_time - iat_time).to be_within(60).of(7.days.to_i)
    end
  end

  describe '.encode_password_reset_token' do
    it 'encodes password reset token with correct type' do
      token = described_class.encode_password_reset_token(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      expect(payload['type']).to eq('password_reset')
      expect(payload['user_id']).to eq(user.id)
    end

    it 'sets short expiration for password reset token' do
      token = described_class.encode_password_reset_token(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      exp_time = Time.at(payload['exp'])
      iat_time = Time.at(payload['iat'])

      # Password reset token should expire in 1 hour
      expect(exp_time - iat_time).to be_within(60).of(1.hour.to_i)
    end
  end

  describe '.encode_email_verification_token' do
    it 'encodes email verification token with correct type' do
      token = described_class.encode_email_verification_token(user)
      decoded_token = JWT.decode(token, JwtEncodeService::SECRET_KEY, true, { algorithm: 'HS256' })
      payload = decoded_token[0]

      expect(payload['type']).to eq('email_verification')
      expect(payload['user_id']).to eq(user.id)
      expect(payload['email']).to eq(user.email)
    end
  end
end
