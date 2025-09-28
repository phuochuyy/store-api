require 'rails_helper'

RSpec.describe JwtEncodeService, type: :service do
  let(:user) { create(:user, email: 'test@example.com') }

  describe '.encode' do
    context 'with valid user' do
      it 'encodes a JWT token with user data' do
        token = JwtEncodeService.encode(user)

        expect(token).to be_present
        expect(token).to be_a(String)
        expect(token.split('.').length).to eq(3) # JWT has 3 parts
      end

      it 'includes user_id and email in payload' do
        token = JwtEncodeService.encode(user)
        decoded = JwtDecodeService.decode(token)

        expect(decoded['user_id']).to eq(user.id)
        expect(decoded['email']).to eq(user.email)
        expect(decoded['iat']).to be_present
        expect(decoded['exp']).to be_present
      end

      it 'sets default expiry to 24 hours' do
        token = JwtEncodeService.encode(user)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = 24.hours.from_now

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end

    context 'with custom expiry' do
      it 'sets custom expiry time' do
        custom_expiry = 1.hour
        token = JwtEncodeService.encode(user, expiry: custom_expiry)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = Time.current + custom_expiry

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end
  end

  describe '.encode_refresh_token' do
    context 'with valid user' do
      it 'encodes a refresh token' do
        token = JwtEncodeService.encode_refresh_token(user)

        expect(token).to be_present
        expect(token).to be_a(String)
        expect(token.split('.').length).to eq(3)
      end

      it 'includes refresh token type' do
        token = JwtEncodeService.encode_refresh_token(user)
        decoded = JwtDecodeService.decode(token)

        expect(decoded['type']).to eq('refresh')
        expect(decoded['user_id']).to eq(user.id)
      end

      it 'sets default expiry to 7 days' do
        token = JwtEncodeService.encode_refresh_token(user)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = 7.days.from_now

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end

    context 'with custom expiry' do
      it 'sets custom expiry time' do
        custom_expiry = 30.days
        token = JwtEncodeService.encode_refresh_token(user, expiry: custom_expiry)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = Time.current + custom_expiry

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end
  end

  describe '.encode_password_reset_token' do
    context 'with valid user' do
      it 'encodes a password reset token' do
        token = JwtEncodeService.encode_password_reset_token(user)

        expect(token).to be_present
        expect(token).to be_a(String)
        expect(token.split('.').length).to eq(3)
      end

      it 'includes password reset token type' do
        token = JwtEncodeService.encode_password_reset_token(user)
        decoded = JwtDecodeService.decode(token)

        expect(decoded['type']).to eq('password_reset')
        expect(decoded['user_id']).to eq(user.id)
      end

      it 'sets default expiry to 1 hour' do
        token = JwtEncodeService.encode_password_reset_token(user)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = 1.hour.from_now

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end

    context 'with custom expiry' do
      it 'sets custom expiry time' do
        custom_expiry = 2.hours
        token = JwtEncodeService.encode_password_reset_token(user, expiry: custom_expiry)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = Time.current + custom_expiry

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end
  end

  describe '.encode_email_verification_token' do
    context 'with valid user' do
      it 'encodes an email verification token' do
        token = JwtEncodeService.encode_email_verification_token(user)

        expect(token).to be_present
        expect(token).to be_a(String)
        expect(token.split('.').length).to eq(3)
      end

      it 'includes email verification token type' do
        token = JwtEncodeService.encode_email_verification_token(user)
        decoded = JwtDecodeService.decode(token)

        expect(decoded['type']).to eq('email_verification')
        expect(decoded['user_id']).to eq(user.id)
        expect(decoded['email']).to eq(user.email)
      end

      it 'sets default expiry to 24 hours' do
        token = JwtEncodeService.encode_email_verification_token(user)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = 24.hours.from_now

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end

    context 'with custom expiry' do
      it 'sets custom expiry time' do
        custom_expiry = 48.hours
        token = JwtEncodeService.encode_email_verification_token(user, expiry: custom_expiry)
        decoded = JwtDecodeService.decode(token)

        exp_time = Time.zone.at(decoded['exp'])
        expected_exp = Time.current + custom_expiry

        expect(exp_time).to be_within(1.minute).of(expected_exp)
      end
    end
  end

  describe 'token security' do
    it 'uses the same secret key for encoding and decoding' do
      token = JwtEncodeService.encode(user)
      decoded = JwtDecodeService.decode(token)

      expect(decoded).to be_present
      expect(decoded['user_id']).to eq(user.id)
    end

    it 'generates different tokens for same user' do
      token1 = JwtEncodeService.encode(user)
      sleep(1) # Ensure different timestamp
      token2 = JwtEncodeService.encode(user)

      expect(token1).not_to eq(token2)
    end

    it 'includes issued at time' do
      token = JwtEncodeService.encode(user)
      decoded = JwtDecodeService.decode(token)

      iat_time = Time.zone.at(decoded['iat'])
      expect(iat_time).to be_within(1.minute).of(Time.current)
    end
  end
end
