require 'rails_helper'

RSpec.describe CategorySerializer, type: :serializer do
  let(:category) { create(:category, name: 'Smartphones', description: 'Mobile phones and accessories') }
  let(:serializer) { described_class.new(category) }

  describe '#as_json' do
    it 'returns serialized category data' do
      result = serializer.as_json

      expect(result).to include(
        id: category.id,
        name: 'Smartphones',
        description: 'Mobile phones and accessories',
        phones_count: 0,
        created_at: category.created_at.iso8601,
        updated_at: category.updated_at.iso8601
      )
    end

    it 'includes icon_url' do
      result = serializer.as_json
      expect(result).to have_key(:icon_url)
    end

    it 'includes phones_count' do
      create(:phone, category: category)
      result = serializer.as_json
      expect(result[:phones_count]).to eq(1)
    end

    it 'handles nil timestamps gracefully' do
      # Test that serializer handles nil timestamps without crashing
      # Since database has NOT NULL constraints, we'll test the logic directly
      allow(category).to receive(:created_at).and_return(nil)
      allow(category).to receive(:updated_at).and_return(nil)
      result = serializer.as_json
      expect(result[:created_at]).to be_nil
      expect(result[:updated_at]).to be_nil
    end
  end

  describe 'initialization' do
    it 'accepts a category object' do
      expect(serializer).to be_present
    end
  end
end
