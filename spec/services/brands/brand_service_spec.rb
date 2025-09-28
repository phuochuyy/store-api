require 'rails_helper'

RSpec.describe Brands::BrandService, type: :service do
  let!(:brand1) { create(:brand, name: 'Apple') }
  let!(:brand2) { create(:brand, name: 'Samsung') }
  let!(:brand3) { create(:brand, name: 'Google') }

  describe '.list_brands' do
    context 'without pagination' do
      it 'returns all brands with default pagination' do
        result = Brands::BrandService.list_brands

        expect(result[:brands]).to be_an(Array)
        expect(result[:brands].length).to eq(3)
        expect(result[:pagination]).to be_present
        expect(result[:pagination][:current_page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(10)
      end
    end

    context 'with pagination' do
      it 'returns paginated brands' do
        result = Brands::BrandService.list_brands(pagination: { page: 1, per_page: 2 })

        expect(result[:brands].length).to eq(2)
        expect(result[:pagination][:current_page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(2)
        expect(result[:pagination][:total_pages]).to eq(2)
      end

      it 'returns second page of brands' do
        result = Brands::BrandService.list_brands(pagination: { page: 2, per_page: 2 })

        expect(result[:brands].length).to eq(1)
        expect(result[:pagination][:current_page]).to eq(2)
      end
    end

    it 'includes phones count in brand data' do
      create(:phone, brand: brand1)
      result = Brands::BrandService.list_brands

      brand_data = result[:brands].find { |b| b[:id] == brand1.id }
      expect(brand_data).to be_present
    end
  end

  describe '.find_brand' do
    context 'with valid brand id' do
      it 'returns brand details' do
        result = Brands::BrandService.find_brand(brand1.id)

        expect(result[:brand]).to be_present
        expect(result[:brand][:id]).to eq(brand1.id)
        expect(result[:brand][:name]).to eq('Apple')
        expect(result[:phones_count]).to eq(0)
      end

      it 'includes phones count' do
        create(:phone, brand: brand1)
        result = Brands::BrandService.find_brand(brand1.id)

        expect(result[:phones_count]).to eq(1)
      end
    end

    context 'with invalid brand id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Brands::BrandService.find_brand(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.create_brand' do
    let(:valid_params) { { name: 'New Brand', description: 'A new brand' } }

    context 'with valid parameters' do
      it 'creates a new brand' do
        expect do
          result = Brands::BrandService.create_brand(valid_params)
          expect(result[:success]).to be true
          expect(result[:brand]).to be_present
          expect(result[:brand][:name]).to eq('New Brand')
        end.to change(Brand, :count).by(1)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing name' do
        invalid_params = { description: 'A brand without name' }
        result = Brands::BrandService.create_brand(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Name can't be blank")
      end

      it 'returns error for duplicate name' do
        invalid_params = { name: 'Apple', description: 'Duplicate name' }
        result = Brands::BrandService.create_brand(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Name has already been taken')
      end

      it 'returns error for name too short' do
        invalid_params = { name: 'A', description: 'Too short' }
        result = Brands::BrandService.create_brand(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Name is too short (minimum is 2 characters)')
      end
    end
  end

  describe '.update_brand' do
    let(:update_params) { { name: 'Updated Brand', description: 'Updated description' } }

    context 'with valid parameters' do
      it 'updates the brand' do
        result = Brands::BrandService.update_brand(brand1.id, update_params)

        expect(result[:success]).to be true
        expect(result[:brand][:name]).to eq('Updated Brand')
        expect(result[:brand][:description]).to eq('Updated description')

        brand1.reload
        expect(brand1.name).to eq('Updated Brand')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid data' do
        invalid_params = { name: '', description: 'Invalid name' }
        result = Brands::BrandService.update_brand(brand1.id, invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Name can't be blank")
      end

      it 'does not update the brand with invalid data' do
        original_name = brand1.name
        invalid_params = { name: '', description: 'Invalid name' }
        Brands::BrandService.update_brand(brand1.id, invalid_params)

        expect(brand1.reload.name).to eq(original_name)
      end
    end

    context 'with invalid brand id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Brands::BrandService.update_brand(99_999, update_params)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.delete_brand' do
    context 'with valid brand id' do
      it 'deletes the brand' do
        expect do
          result = Brands::BrandService.delete_brand(brand1.id)
          expect(result[:success]).to be true
        end.to change(Brand, :count).by(-1)
      end
    end

    context 'with invalid brand id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Brands::BrandService.delete_brand(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when brand has associated phones' do
      let!(:phone) { create(:phone, brand: brand1) }

      it 'deletes the brand and associated phones' do
        expect do
          result = Brands::BrandService.delete_brand(brand1.id)
          expect(result[:success]).to be true
        end.to change(Brand, :count).by(-1)
                                    .and change(Phone, :count).by(-1)
      end
    end
  end
end
