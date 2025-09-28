require 'rails_helper'

RSpec.describe ProductSerializer, type: :serializer do
  let(:brand) { create(:brand, name: 'Apple') }
  let(:category) { create(:category, name: 'Smartphones') }
  let(:product) do
    create(:product,
           name: 'iPhone 15',
           description: 'Latest iPhone model',
           price: 999.99,
           stock_quantity: 10,
           brand: brand,
           category: category)
  end
  let(:serializer) { described_class.new(product) }

  describe '#as_json' do
    it 'returns serialized product data' do
      result = serializer.as_json

      expect(result).to include(
        id: product.id,
        name: 'iPhone 15',
        description: 'Latest iPhone model',
        price: 999.99,
        stock_quantity: 10,
        in_stock: true,
        created_at: product.created_at.iso8601,
        updated_at: product.updated_at.iso8601
      )
    end

    it 'includes brand information' do
      result = serializer.as_json

      expect(result[:brand]).to include(
        id: brand.id,
        name: 'Apple'
      )
    end

    it 'includes category information' do
      result = serializer.as_json

      expect(result[:category]).to include(
        id: category.id,
        name: 'Smartphones'
      )
    end

    it 'returns nil for image_url when no image attached' do
      result = serializer.as_json

      expect(result[:image_url]).to be_nil
    end

    it 'returns empty hash for specifications when nil' do
      result = serializer.as_json

      expect(result[:specifications]).to eq({})
    end

    context 'with string specifications' do
      let(:specs) { '{"color": "black", "storage": "128GB"}' }

      before do
        product.update(specifications: specs)
      end

      it 'parses JSON specifications' do
        result = serializer.as_json

        expect(result[:specifications]).to eq({
                                                'color' => 'black',
                                                'storage' => '128GB'
                                              })
      end
    end

    context 'with hash specifications' do
      let(:specs) { { 'color' => 'black', 'storage' => '128GB' } }

      before do
        allow(product).to receive(:specifications).and_return(specs)
      end

      it 'returns hash specifications directly' do
        result = serializer.as_json

        expect(result[:specifications]).to eq(specs)
      end
    end

    context 'with invalid JSON specifications' do
      let(:invalid_specs) { 'invalid json' }

      before do
        product.update(specifications: invalid_specs)
      end

      it 'returns empty hash for invalid JSON' do
        result = serializer.as_json

        expect(result[:specifications]).to eq({})
      end
    end

    context 'with out of stock product' do
      before do
        product.update(stock_quantity: 0)
      end

      it 'returns in_stock as false' do
        result = serializer.as_json

        expect(result[:in_stock]).to be false
      end
    end

    context 'with nil timestamps' do
      before do
        allow(product).to receive(:created_at).and_return(nil)
        allow(product).to receive(:updated_at).and_return(nil)
      end

      it 'handles nil timestamps gracefully' do
        result = serializer.as_json

        expect(result[:created_at]).to be_nil
        expect(result[:updated_at]).to be_nil
      end
    end
  end
end
