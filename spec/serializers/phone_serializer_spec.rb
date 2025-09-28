require 'rails_helper'

RSpec.describe PhoneSerializer, type: :serializer do
  let(:brand) { create(:brand, name: 'Apple') }
  let(:category) { create(:category, name: 'Smartphones') }
  let(:phone) do
    create(:phone,
           name: 'iPhone 15',
           description: 'Latest iPhone model',
           price: 999.99,
           stock_quantity: 10,
           brand: brand,
           category: category)
  end
  let(:serializer) { described_class.new(phone) }

  describe '#as_json' do
    it 'returns serialized phone data' do
      result = serializer.as_json

      expect(result).to include(
        id: phone.id,
        name: 'iPhone 15',
        description: 'Latest iPhone model',
        price: 999.99,
        stock_quantity: 10,
        in_stock: true,
        created_at: phone.created_at.iso8601,
        updated_at: phone.updated_at.iso8601
      )
    end

    it 'includes image_url' do
      result = serializer.as_json
      expect(result).to have_key(:image_url)
    end

    it 'includes specifications' do
      result = serializer.as_json
      expect(result).to have_key(:specifications)
    end

    it 'includes brand data' do
      result = serializer.as_json
      expect(result[:brand]).to include(
        id: brand.id,
        name: 'Apple'
      )
    end

    it 'includes category data' do
      result = serializer.as_json
      expect(result[:category]).to include(
        id: category.id,
        name: 'Smartphones'
      )
    end

    it 'shows in_stock as false when stock is zero' do
      phone.update(stock_quantity: 0)
      result = serializer.as_json
      expect(result[:in_stock]).to be false
    end

    it 'handles nil timestamps gracefully' do
      # Test that serializer handles nil timestamps without crashing
      # Since database has NOT NULL constraints, we'll test the logic directly
      allow(phone).to receive(:created_at).and_return(nil)
      allow(phone).to receive(:updated_at).and_return(nil)
      result = serializer.as_json
      expect(result[:created_at]).to be_nil
      expect(result[:updated_at]).to be_nil
    end
  end

  describe 'specifications handling' do
    context 'with valid JSON specifications' do
      it 'parses JSON specifications' do
        phone.update(specifications: '{"screen": "6.1 inch", "storage": "128GB"}')
        result = serializer.as_json
        expect(result[:specifications]).to eq({ 'screen' => '6.1 inch', 'storage' => '128GB' })
      end
    end

    context 'with invalid JSON specifications' do
      it 'returns empty hash for invalid JSON' do
        phone.update(specifications: 'invalid json')
        result = serializer.as_json
        expect(result[:specifications]).to eq({})
      end
    end

    context 'with blank specifications' do
      it 'returns empty hash for blank specifications' do
        phone.update(specifications: '')
        result = serializer.as_json
        expect(result[:specifications]).to eq({})
      end

      it 'returns empty hash for nil specifications' do
        phone.update(specifications: nil)
        result = serializer.as_json
        expect(result[:specifications]).to eq({})
      end
    end

    context 'with hash specifications' do
      it 'returns hash as is' do
        specs = { 'screen' => '6.1 inch', 'storage' => '128GB' }
        # Mock the specifications to return the hash directly
        allow(phone).to receive(:specifications).and_return(specs)
        result = serializer.as_json
        expect(result[:specifications]).to eq(specs)
      end
    end
  end

  describe 'initialization' do
    it 'accepts a phone object' do
      expect(serializer).to be_present
    end
  end
end
