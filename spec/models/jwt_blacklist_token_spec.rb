require 'rails_helper'

RSpec.describe JwtBlacklistToken, type: :model do
  describe 'validations' do
    it 'validates presence of token' do
      blacklist_token = JwtBlacklistToken.new(expires_at: 1.hour.from_now)
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:token]).to include("can't be blank")
    end

    it 'validates presence of expires_at' do
      blacklist_token = JwtBlacklistToken.new(token: 'test_token')
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:expires_at]).to include("can't be blank")
    end

    it 'validates uniqueness of token' do
      create(:jwt_blacklist_token, token: 'duplicate_token')
      blacklist_token = build(:jwt_blacklist_token, token: 'duplicate_token')
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:token]).to include('has already been taken')
    end

    it 'validates inclusion of token_type' do
      blacklist_token = build(:jwt_blacklist_token, token_type: 'invalid_type')
      expect(blacklist_token).not_to be_valid
      expect(blacklist_token.errors[:token_type]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    let!(:active_token) { create(:jwt_blacklist_token, expires_at: 1.hour.from_now) }
    let!(:expired_token) { create(:jwt_blacklist_token, expires_at: 1.hour.ago) }
    let!(:refresh_token) { create(:jwt_blacklist_token, :refresh_token) }

    it 'returns active tokens' do
      expect(JwtBlacklistToken.active).to include(active_token)
      expect(JwtBlacklistToken.active).not_to include(expired_token)
    end

    it 'returns expired tokens' do
      expect(JwtBlacklistToken.expired).to include(expired_token)
      expect(JwtBlacklistToken.expired).not_to include(active_token)
    end

    it 'filters by token type' do
      expect(JwtBlacklistToken.by_token_type('refresh')).to include(refresh_token)
      expect(JwtBlacklistToken.by_token_type('refresh')).not_to include(active_token)
    end

    it 'filters by user' do
      user_token = create(:jwt_blacklist_token, user_id: '123')
      expect(JwtBlacklistToken.by_user('123')).to include(user_token)
      expect(JwtBlacklistToken.by_user('123')).not_to include(active_token)
    end
  end

  describe 'class methods' do
    describe '.blacklisted?' do
      it 'returns true for blacklisted token' do
        create(:jwt_blacklist_token, token: 'blacklisted_token')
        expect(JwtBlacklistToken.blacklisted?('blacklisted_token')).to be true
      end

      it 'returns false for non-blacklisted token' do
        expect(JwtBlacklistToken.blacklisted?('valid_token')).to be false
      end

      it 'returns false for expired token' do
        create(:jwt_blacklist_token, token: 'expired_token', expires_at: 1.hour.ago)
        expect(JwtBlacklistToken.blacklisted?('expired_token')).to be false
      end

      it 'returns false for blank token' do
        expect(JwtBlacklistToken.blacklisted?('')).to be false
        expect(JwtBlacklistToken.blacklisted?(nil)).to be false
      end
    end

    describe '.blacklist_token' do
      it 'creates a new blacklist token' do
        expect do
          JwtBlacklistToken.blacklist_token('new_token', expires_at: 1.hour.from_now)
        end.to change(JwtBlacklistToken, :count).by(1)
      end

      it 'returns false for blank token' do
        expect(JwtBlacklistToken.blacklist_token('')).to be false
        expect(JwtBlacklistToken.blacklist_token(nil)).to be false
      end

      it 'handles duplicate tokens gracefully' do
        JwtBlacklistToken.blacklist_token('duplicate_token', expires_at: 1.hour.from_now)
        expect(JwtBlacklistToken.blacklist_token('duplicate_token', expires_at: 1.hour.from_now)).to be true
      end
    end

    describe '.cleanup_expired' do
      it 'removes expired tokens' do
        create(:jwt_blacklist_token, expires_at: 1.hour.ago)
        create(:jwt_blacklist_token, expires_at: 1.hour.from_now)

        expect do
          JwtBlacklistToken.cleanup_expired
        end.to change(JwtBlacklistToken, :count).by(-1)
      end
    end

    describe '.stats' do
      it 'returns statistics' do
        create(:jwt_blacklist_token, expires_at: 1.hour.from_now)
        create(:jwt_blacklist_token, expires_at: 1.hour.ago)
        create(:jwt_blacklist_token, :refresh_token)

        stats = JwtBlacklistToken.stats
        expect(stats[:total]).to eq(3)
        expect(stats[:active]).to eq(2)
        expect(stats[:expired]).to eq(1)
        expect(stats[:by_type]['access']).to eq(2)
        expect(stats[:by_type]['refresh']).to eq(1)
      end
    end
  end

  describe 'instance methods' do
    let(:active_token) { create(:jwt_blacklist_token, expires_at: 1.hour.from_now) }
    let(:expired_token) { create(:jwt_blacklist_token, expires_at: 1.hour.ago) }

    describe '#expired?' do
      it 'returns false for active token' do
        expect(active_token.expired?).to be false
      end

      it 'returns true for expired token' do
        expect(expired_token.expired?).to be true
      end
    end

    describe '#active?' do
      it 'returns true for active token' do
        expect(active_token.active?).to be true
      end

      it 'returns false for expired token' do
        expect(expired_token.active?).to be false
      end
    end
  end
end
