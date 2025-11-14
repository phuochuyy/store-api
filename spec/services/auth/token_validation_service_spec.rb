require 'rails_helper'

RSpec.describe Auth::TokenValidationService, type: :service do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:valid_token) do
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, Auth::Jwt::Config::SECRET_KEY, 'HS256')
  end

  describe '.authenticate' do
    context 'with valid token' do
      it 'returns success with user' do
        result = described_class.authenticate(valid_token)

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:error]).to be_nil
      end
    end

    context 'with invalid token' do
      it 'returns failure for blank token' do
        result = described_class.authenticate('')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token is blank')
        expect(result[:user]).to be_nil
      end

      it 'returns failure for malformed token' do
        result = described_class.authenticate('invalid-token')

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
        expect(result[:user]).to be_nil
      end

      it 'returns failure for expired token' do
        expired_payload = {
          user_id: user.id,
          email: user.email,
          role: user.role,
          iat: 2.days.ago.to_i,
          exp: 1.day.ago.to_i
        }
        expired_token = JWT.encode(expired_payload, Rails.application.credentials.secret_key_base, 'HS256')

        result = described_class.authenticate(expired_token)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
        expect(result[:user]).to be_nil
      end
    end

    context 'with blacklisted token' do
      it 'returns failure for blacklisted token' do
        Auth::Jwt::BlacklistService.blacklist_token(valid_token)

        result = described_class.authenticate(valid_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token has been revoked')
        expect(result[:user]).to be_nil
      end
    end
  end

  describe '.authorize' do
    let(:resource) { create(:user) }

    context 'with valid user and resource' do
      it 'returns success for admin user' do
        admin_user = create(:user, :admin)
        result = described_class.authorize(admin_user, resource, 'show')

        expect(result[:success]).to be true
        expect(result[:error]).to be_nil
      end

      it 'returns success for resource owner' do
        result = described_class.authorize(user, user, 'show')

        expect(result[:success]).to be true
        expect(result[:error]).to be_nil
      end
    end

    context 'with invalid user' do
      it 'returns failure for nil user' do
        result = described_class.authorize(nil, resource, 'show')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not authenticated')
      end

      it 'returns failure for unauthorized user' do
        other_user = create(:user)
        result = described_class.authorize(other_user, resource, 'update')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Access denied')
      end
    end

    context 'with missing policy' do
      it 'returns failure for non-existent policy' do
        result = described_class.authorize(user, 'string_resource', 'show')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Authorization policy not found')
      end
    end

    context 'with policy errors' do
      it 'handles policy errors gracefully' do
        allow_any_instance_of(UserPolicy).to receive(:show?).and_raise(StandardError, 'Policy error')

        result = described_class.authorize(user, user, 'show')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Authorization failed')
      end
    end
  end
end


