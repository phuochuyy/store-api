require 'rails_helper'

RSpec.describe BrandSerializer, type: :serializer do
  let(:brand) { create(:brand, name: 'Apple', description: 'Premium technology brand') }
  let(:serializer) { described_class.new(brand) }

  describe '#as_json' do
    it 'returns serialized brand data' do
      result = serializer.as_json

      expect(result).to include(
        id: brand.id,
        name: 'Apple',
        description: 'Premium technology brand',
        phones_count: 0,
        created_at: brand.created_at.iso8601,
        updated_at: brand.updated_at.iso8601
      )
    end

    it 'includes logo_url' do
      result = serializer.as_json
      expect(result).to have_key(:logo_url)
    end

    it 'includes phones_count' do
      create(:phone, brand: brand)
      result = serializer.as_json
      expect(result[:phones_count]).to eq(1)
    end

    it 'handles nil timestamps gracefully' do
      # Test that serializer handles nil timestamps without crashing
      # Since database has NOT NULL constraints, we'll test the logic directly
      allow(brand).to receive(:created_at).and_return(nil)
      allow(brand).to receive(:updated_at).and_return(nil)
      result = serializer.as_json
      expect(result[:created_at]).to be_nil
      expect(result[:updated_at]).to be_nil
    end
  end

  describe 'initialization' do
    it 'accepts a brand object' do
      expect(serializer).to be_present
    end
  end
end
