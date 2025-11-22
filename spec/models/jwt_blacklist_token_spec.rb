require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe JwtBlacklistToken, type: :model do
  describe 'validations' do
    it 'requires a token' do
      blacklist_token = build(:jwt_blacklist_token, token: nil)
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:token]).to include("can't be blank")
    end

    it 'requires a unique token' do
      create(:jwt_blacklist_token, token: 'unique-token')
      new_token = build(:jwt_blacklist_token, token: 'unique-token')
      expect(new_token).not_to be_valid
      expect(new_token.errors[:token]).to include('has already been taken')
    end

    it 'requires an expires_at' do
      blacklist_token = build(:jwt_blacklist_token, expires_at: nil)
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:expires_at]).to include("can't be blank")
    end

    it 'validates token_type inclusion' do
      valid_token = build(:jwt_blacklist_token, token_type: 'access')
      expect(valid_token).to be_valid

      invalid_token = build(:jwt_blacklist_token, token_type: 'invalid')
      expect(invalid_token).not_to be_valid
      expect(invalid_token.errors[:token_type]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    let!(:expired_token) { create(:jwt_blacklist_token, :expired) }
    let!(:active_token) { create(:jwt_blacklist_token) }

    it 'filters expired tokens' do
      expect(JwtBlacklistToken.expired).to include(expired_token)
      expect(JwtBlacklistToken.expired).not_to include(active_token)
    end

    it 'filters active tokens' do
      expect(JwtBlacklistToken.active).to include(active_token)
      expect(JwtBlacklistToken.active).not_to include(expired_token)
    end

    it 'filters by token type' do
      access_token = create(:jwt_blacklist_token, token_type: 'access')
      refresh_token = create(:jwt_blacklist_token, :refresh_token)

      expect(JwtBlacklistToken.by_token_type('access')).to include(access_token)
      expect(JwtBlacklistToken.by_token_type('access')).not_to include(refresh_token)
    end

    it 'filters by user' do
      user = create(:user)
      user_token = create(:jwt_blacklist_token, :with_user, user_id: user.id.to_s)
      other_token = create(:jwt_blacklist_token)

      expect(JwtBlacklistToken.by_user(user.id.to_s)).to include(user_token)
      expect(JwtBlacklistToken.by_user(user.id.to_s)).not_to include(other_token)
    end
  end

  describe 'class methods' do
    describe '.blacklisted?' do
      it 'returns true for blacklisted token' do
        create(:jwt_blacklist_token, token: 'test-token')
        expect(JwtBlacklistToken.blacklisted?('test-token')).to be true
      end

      it 'returns false for non-blacklisted token' do
        expect(JwtBlacklistToken.blacklisted?('non-existent-token')).to be false
      end

      it 'returns false for expired token' do
        create(:jwt_blacklist_token, :expired, token: 'expired-token')
        expect(JwtBlacklistToken.blacklisted?('expired-token')).to be false
      end

      it 'returns false for blank token' do
        expect(JwtBlacklistToken.blacklisted?('')).to be false
        expect(JwtBlacklistToken.blacklisted?(nil)).to be false
      end
    end

    describe '.blacklist_token' do
      let(:user) { create(:user) }
      let(:valid_token) { 'valid.jwt.token' }

      it 'creates a new blacklist entry' do
        expect do
          JwtBlacklistToken.blacklist_token(valid_token, user_id: user.id.to_s)
        end.to change(JwtBlacklistToken, :count).by(1)

        token = JwtBlacklistToken.last
        expect(token.token).to eq(valid_token)
        expect(token.user_id).to eq(user.id.to_s)
        expect(token.token_type).to eq('access')
      end

      it 'does not create duplicate entries' do
        JwtBlacklistToken.blacklist_token(valid_token)

        expect do
          JwtBlacklistToken.blacklist_token(valid_token)
        end.not_to change(JwtBlacklistToken, :count)
      end

      it 'returns false for blank token' do
        expect(JwtBlacklistToken.blacklist_token('')).to be false
        expect(JwtBlacklistToken.blacklist_token(nil)).to be false
      end

      it 'handles different token types' do
        JwtBlacklistToken.blacklist_token(valid_token, token_type: 'refresh')

        token = JwtBlacklistToken.last
        expect(token.token_type).to eq('refresh')
      end
    end

    describe '.cleanup_expired' do
      it 'removes expired tokens' do
        expired_token = create(:jwt_blacklist_token, :expired)
        active_token = create(:jwt_blacklist_token)

        expect do
          JwtBlacklistToken.cleanup_expired
        end.to change(JwtBlacklistToken, :count).by(-1)

        expect(JwtBlacklistToken.exists?(expired_token.id)).to be false
        expect(JwtBlacklistToken.exists?(active_token.id)).to be true
      end
    end

    describe '.stats' do
      it 'returns blacklist statistics' do
        # Create test tokens
        create(:jwt_blacklist_token, token_type: 'access')
        create(:jwt_blacklist_token, :refresh_token)
        create(:jwt_blacklist_token, :expired)

        stats = JwtBlacklistToken.stats

        # Check that stats structure is correct
        expect(stats).to include(:total, :active, :expired, :by_type, :by_user)
        expect(stats[:total]).to be >= 3
        expect(stats[:active]).to be >= 2
        expect(stats[:expired]).to be >= 1
        expect(stats[:by_type]).to include('access', 'refresh')
        expect(stats[:by_type]['access']).to be >= 1
        expect(stats[:by_type]['refresh']).to be >= 1
      end
    end
  end

  describe 'instance methods' do
    let(:active_token) { create(:jwt_blacklist_token) }
    let(:expired_token) { create(:jwt_blacklist_token, :expired) }

    it 'knows if it is expired' do
      expect(expired_token.expired?).to be true
      expect(active_token.expired?).to be false
    end

    it 'knows if it is active' do
      expect(active_token.active?).to be true
      expect(expired_token.active?).to be false
    end
  end
end
# rubocop:enable Metrics/BlockLength
