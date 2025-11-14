require 'rails_helper'

RSpec.describe PasswordResetToken, type: :model do
  let(:user) { create(:user) }
  let(:token) { create(:password_reset_token, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:token) }
    it { should validate_uniqueness_of(:token) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'scopes' do
    let!(:active_token) { create(:password_reset_token, user: user, expires_at: 1.hour.from_now, used: false) }
    let!(:used_token) { create(:password_reset_token, :used, user: user) }
    let!(:expired_token) { create(:password_reset_token, :expired, user: user) }

    describe '.active' do
      it 'returns only active tokens' do
        expect(PasswordResetToken.active).to include(active_token)
        expect(PasswordResetToken.active).not_to include(used_token, expired_token)
      end
    end
  end

  describe '.generate_for_user' do
    it 'generates token for user' do
      token = PasswordResetToken.generate_for_user(user, ip_address: '127.0.0.1')
      expect(token).to be_persisted
      expect(token.user).to eq(user)
      expect(token.token).to be_present
      expect(token.expires_at).to be > Time.current
    end
  end

  describe '#expired?' do
    it 'returns true when token is expired' do
      expired_token = create(:password_reset_token, :expired, user: user)
      expect(expired_token.expired?).to be true
    end

    it 'returns false when token is not expired' do
      expect(token.expired?).to be false
    end
  end

  describe '#used?' do
    it 'returns true when token is used' do
      used_token = create(:password_reset_token, :used, user: user)
      expect(used_token.used?).to be true
    end
  end

  describe '#active?' do
    it 'returns true when token is active' do
      expect(token.active?).to be true
    end

    it 'returns false when token is expired' do
      expired_token = create(:password_reset_token, :expired, user: user)
      expect(expired_token.active?).to be false
    end

    it 'returns false when token is used' do
      used_token = create(:password_reset_token, :used, user: user)
      expect(used_token.active?).to be false
    end
  end
end

