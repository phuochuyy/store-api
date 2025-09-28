require 'rails_helper'

RSpec.describe UserSerializer, type: :serializer do
  let(:user) { create(:user, name: 'John Doe', email: 'john@example.com', role: 'customer') }
  let(:serializer) { described_class.new(user) }

  describe '#as_json' do
    it 'returns serialized user data' do
      result = serializer.as_json

      expect(result).to include(
        id: user.id,
        name: 'John Doe',
        email: 'john@example.com',
        role: 'customer',
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      )
    end

    it 'does not include password or password_digest' do
      result = serializer.as_json
      expect(result).not_to have_key(:password)
      expect(result).not_to have_key(:password_digest)
    end

    it 'handles admin role' do
      admin_user = create(:user, role: 'admin')
      admin_serializer = described_class.new(admin_user)
      result = admin_serializer.as_json
      expect(result[:role]).to eq('admin')
    end

    it 'handles nil timestamps gracefully' do
      # Test that serializer handles nil timestamps without crashing
      # Since database has NOT NULL constraints, we'll test the logic directly
      allow(user).to receive(:created_at).and_return(nil)
      allow(user).to receive(:updated_at).and_return(nil)
      result = serializer.as_json
      expect(result[:created_at]).to be_nil
      expect(result[:updated_at]).to be_nil
    end
  end

  describe 'initialization' do
    it 'accepts a user object' do
      expect(serializer).to be_present
    end
  end
end
