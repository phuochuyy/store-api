require 'rails_helper'

RSpec.describe Auth::AuthenticationService, type: :service do
  let(:user) { create(:user, role: 'admin') }
  let(:brand) { create(:brand) }

  describe '.authenticate' do
    context 'with valid token' do
      it 'returns success and user' do
        token = JwtEncodeService.encode(user)
        result = Auth::AuthenticationService.authenticate(token)

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:error]).to be_nil
      end
    end

    context 'with invalid token' do
      it 'returns error for blank token' do
        result = Auth::AuthenticationService.authenticate('')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token is blank')
      end

      it 'returns error for nil token' do
        result = Auth::AuthenticationService.authenticate(nil)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token is blank')
      end

      it 'returns error for malformed token' do
        result = Auth::AuthenticationService.authenticate('invalid_token')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid token format')
      end

      it 'returns error for expired token' do
        # Create a token that expires in the past
        payload = {
          user_id: user.id,
          email: user.email,
          iat: Time.current.to_i,
          exp: 1.hour.ago.to_i
        }
        expired_token = JWT.encode(payload, JwtEncodeService::SECRET_KEY, 'HS256')
        result = Auth::AuthenticationService.authenticate(expired_token)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid token format')
      end
    end

    context 'with non-existent user' do
      it 'returns error for non-existent user' do
        payload = {
          user_id: 99_999,
          email: 'nonexistent@example.com',
          iat: Time.current.to_i,
          exp: 1.hour.from_now.to_i
        }
        token = JWT.encode(payload, JwtEncodeService::SECRET_KEY, 'HS256')
        result = Auth::AuthenticationService.authenticate(token)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end
    end
  end

  describe '.authorize' do
    context 'with valid user and resource' do
      it 'returns success for admin user accessing brand' do
        result = Auth::AuthenticationService.authorize(user, brand, :create)
        expect(result[:success]).to be true
        expect(result[:error]).to be_nil
      end

      it 'returns success for admin user accessing brand show' do
        result = Auth::AuthenticationService.authorize(user, brand, :show)
        expect(result[:success]).to be true
      end
    end

    context 'with customer user' do
      let(:customer_user) { create(:user, role: 'customer') }

      it 'returns success for customer accessing brand show' do
        result = Auth::AuthenticationService.authorize(customer_user, brand, :show)
        expect(result[:success]).to be true
      end

      it 'returns error for customer accessing brand create' do
        result = Auth::AuthenticationService.authorize(customer_user, brand, :create)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Access denied')
      end
    end

    context 'with nil user' do
      it 'returns error for unauthenticated user' do
        result = Auth::AuthenticationService.authorize(nil, brand, :show)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not authenticated')
      end
    end

    context 'with non-existent policy' do
      it 'returns error for resource without policy' do
        # Create a mock class that doesn't have a policy
        mock_resource = double('MockResource', class: double('MockClass', name: 'MockResource'))
        result = Auth::AuthenticationService.authorize(user, mock_resource, :show)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Authorization policy not found')
      end
    end

    context 'with user policy' do
      let(:other_user) { create(:user, role: 'customer') }

      it 'returns success for user accessing their own profile' do
        result = Auth::AuthenticationService.authorize(user, user, :show)
        expect(result[:success]).to be true
      end

      it 'returns success for admin accessing any user profile' do
        result = Auth::AuthenticationService.authorize(user, other_user, :show)
        expect(result[:success]).to be true
      end

      it 'returns error for user accessing other user profile' do
        result = Auth::AuthenticationService.authorize(other_user, user, :show)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Access denied')
      end
    end
  end
end
