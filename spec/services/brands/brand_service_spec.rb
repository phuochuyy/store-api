require 'rails_helper'

RSpec.describe Brands::BrandService, type: :service do
  describe '.list_brands' do
    context 'without pagination' do
      it 'returns all brands with default pagination' do
        create_list(:brand, 5)
        result = described_class.list_brands

        expect(result).to include(:brands, :pagination)
        expect(result[:brands]).to be_an(Array)
        expect(result[:pagination]).to include(
          :current_page,
          :total_pages,
          :total_count,
          :per_page
        )
      end

      it 'includes products in brand serialization' do
        brand = create(:brand)
        create(:product, brand: brand)
        result = described_class.list_brands

        expect(result[:brands].first).to be_a(Hash)
      end
    end

    context 'with pagination' do
      it 'returns paginated brands' do
        create_list(:brand, 15)
        result = described_class.list_brands(pagination: { page: 1, per_page: 10 })

        expect(result[:brands].length).to eq(10)
        expect(result[:pagination][:current_page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(10)
        expect(result[:pagination][:total_count]).to eq(15)
      end

      it 'handles page 2 correctly' do
        create_list(:brand, 15)
        result = described_class.list_brands(pagination: { page: 2, per_page: 10 })

        expect(result[:brands].length).to eq(5)
        expect(result[:pagination][:current_page]).to eq(2)
      end

      it 'returns empty array when page exceeds total pages' do
        create_list(:brand, 5)
        result = described_class.list_brands(pagination: { page: 10, per_page: 10 })

        expect(result[:brands]).to be_empty
      end
    end

    context 'with brands that have products' do
      it 'includes products in the result' do
        brand = create(:brand)
        create(:product, brand: brand)
        result = described_class.list_brands

        expect(result[:brands].first).to be_a(Hash)
      end
    end
  end

  describe '.find_brand' do
    let(:brand) { create(:brand) }

    it 'returns brand with serialized data' do
      result = described_class.find_brand(brand.id)

      expect(result).to include(:brand, :products_count)
      expect(result[:brand]).to be_a(Hash)
      expect(result[:brand]['id']).to eq(brand.id)
      expect(result[:brand]['name']).to eq(brand.name)
      expect(result[:brand]['description']).to eq(brand.description)
    end

    it 'returns products count' do
      create_list(:product, 3, brand: brand)
      result = described_class.find_brand(brand.id)

      expect(result[:products_count]).to eq(3)
    end

    it 'includes products in brand serialization' do
      create(:product, brand: brand)
      result = described_class.find_brand(brand.id)

      expect(result[:brand]).to be_a(Hash)
    end

    it 'raises error for non-existent brand' do
      expect do
        described_class.find_brand(99999)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.create_brand' do
    let(:valid_params) do
      {
        name: 'New Brand',
        description: 'This is a valid brand description that meets the minimum length requirement'
      }
    end

    context 'with valid params' do
      it 'creates a new brand' do
        expect do
          described_class.create_brand(valid_params)
        end.to change { Brand.count }.by(1)
      end

      it 'returns success with brand data' do
        result = described_class.create_brand(valid_params)

        expect(result[:success]).to be true
        expect(result[:brand]).to be_a(Hash)
        expect(result[:brand]['name']).to eq('New Brand')
        expect(result[:errors]).to be_nil
      end
    end

    context 'with invalid params' do
      it 'returns failure with errors for short name' do
        invalid_params = { name: 'A', description: 'Valid description that meets minimum length' }
        result = described_class.create_brand(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:brand]).to be_nil
      end

      it 'returns failure with errors for short description' do
        invalid_params = { name: 'Valid Name', description: 'Short' }
        result = described_class.create_brand(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns failure with errors for duplicate name' do
        create(:brand, name: 'Existing Brand')
        duplicate_params = {
          name: 'Existing Brand',
          description: 'This is a valid brand description that meets the minimum length requirement'
        }
        result = described_class.create_brand(duplicate_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'does not create brand when validation fails' do
        invalid_params = { name: 'A', description: 'Short' }
        expect do
          described_class.create_brand(invalid_params)
        end.not_to change { Brand.count }
      end
    end
  end

  describe '.update_brand' do
    let(:brand) { create(:brand) }

    context 'with valid params' do
      it 'updates brand successfully' do
        update_params = {
          name: 'Updated Brand Name',
          description: 'This is an updated brand description that meets the minimum length requirement'
        }
        result = described_class.update_brand(brand.id, update_params)

        expect(result[:success]).to be true
        expect(result[:brand]).to be_a(Hash)
        expect(result[:errors]).to be_nil
      end

      it 'updates brand attributes' do
        update_params = { name: 'Updated Name' }
        described_class.update_brand(brand.id, update_params)

        brand.reload
        expect(brand.name).to eq('Updated Name')
      end

      it 'returns updated brand data' do
        update_params = { name: 'Updated Brand Name' }
        result = described_class.update_brand(brand.id, update_params)

        expect(result[:brand]['name']).to eq('Updated Brand Name')
      end
    end

    context 'with invalid params' do
      it 'returns failure with errors for short name' do
        invalid_params = { name: 'A' }
        result = described_class.update_brand(brand.id, invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns failure with errors for duplicate name' do
        other_brand = create(:brand, name: 'Other Brand')
        duplicate_params = { name: 'Other Brand' }
        result = described_class.update_brand(brand.id, duplicate_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'does not update brand when validation fails' do
        original_name = brand.name
        invalid_params = { name: 'A' }
        described_class.update_brand(brand.id, invalid_params)

        brand.reload
        expect(brand.name).to eq(original_name)
      end
    end

    it 'raises error for non-existent brand' do
      expect do
        described_class.update_brand(99999, { name: 'Test' })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.delete_brand' do
    let(:brand) { create(:brand) }

    it 'deletes brand successfully' do
      brand_id = brand.id
      result = described_class.delete_brand(brand_id)

      expect(result[:success]).to be true
      expect(Brand.find_by(id: brand_id)).to be_nil
    end

    it 'deletes associated products' do
      product1 = create(:product, brand: brand)
      product2 = create(:product, brand: brand)

      described_class.delete_brand(brand.id)

      expect(Product.find_by(id: product1.id)).to be_nil
      expect(Product.find_by(id: product2.id)).to be_nil
    end

    it 'raises error for non-existent brand' do
      expect do
        described_class.delete_brand(99999)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

