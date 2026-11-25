require 'rails_helper'

RSpec.describe JwtBlacklistToken do
  # Real access tokens are about 270 characters, and they grow with the payload.
  let(:long_token) { "header.#{'a' * 1_000}.signature" }

  describe '.blacklist_token' do
    it 'blacklists a token of any length' do
      described_class.blacklist_token(long_token, expires_at: 1.hour.from_now)

      expect(described_class.blacklisted?(long_token)).to be true
      expect(described_class.blacklisted?("#{long_token}x")).to be false
    end

    it 'stores a SHA-256 digest, never the token itself' do
      described_class.blacklist_token(long_token, expires_at: 1.hour.from_now)

      expect(described_class.sole.token_digest).to eq(Digest::SHA256.hexdigest(long_token))
      expect(described_class.column_names).not_to include('token')
    end

    it 'keeps a single row when the same token is blacklisted again' do
      described_class.blacklist_token(long_token, expires_at: 1.hour.from_now, reason: 'first')
      described_class.blacklist_token(long_token, expires_at: 2.hours.from_now, reason: 'second')

      expect(described_class.sole.reason).to eq('second')
    end
  end

  describe '.blacklisted?' do
    it 'ignores entries that have expired' do
      described_class.blacklist_token(long_token, expires_at: 1.minute.ago)

      expect(described_class.blacklisted?(long_token)).to be false
    end
  end
end
