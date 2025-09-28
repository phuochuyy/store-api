require 'rails_helper'

RSpec.describe ProductValidator, type: :validator do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }

  describe 'validations' do
    context 'with valid attributes' do
      it 'is valid' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'Latest iPhone model with advanced features',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).to be_valid
      end
    end

    context 'name validation' do
      it 'is invalid without name' do
        validator = ProductValidator.new(
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with name too short' do
        validator = ProductValidator.new(
          name: 'A',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too short (minimum is 2 characters)')
      end

      it 'is invalid with name too long' do
        validator = ProductValidator.new(
          name: 'A' * 101,
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too long (maximum is 100 characters)')
      end
    end

    context 'description validation' do
      it 'is invalid without description' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include("can't be blank")
      end

      it 'is invalid with description too short' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'Short',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too short (minimum is 10 characters)')
      end

      it 'is invalid with description too long' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A' * 1001,
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too long (maximum is 1000 characters)')
      end
    end

    context 'price validation' do
      it 'is invalid without price' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:price]).to include("can't be blank")
      end

      it 'is invalid with negative price' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: -100,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:price]).to include('must be greater than 0')
      end

      it 'is invalid with zero price' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 0,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:price]).to include('must be greater than 0')
      end
    end

    context 'stock_quantity validation' do
      it 'is invalid without stock_quantity' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:stock_quantity]).to include("can't be blank")
      end

      it 'is invalid with negative stock_quantity' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: -1,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:stock_quantity]).to include('must be greater than or equal to 0')
      end

      it 'is valid with zero stock_quantity' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 0,
          brand_id: brand.id,
          category_id: category.id
        )
        expect(validator).to be_valid
      end
    end

    context 'brand_id validation' do
      it 'is invalid without brand_id' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:brand_id]).to include("can't be blank")
      end

      it 'is invalid with non-existent brand_id' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: 99_999,
          category_id: category.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:brand_id]).to include('Brand does not exist')
      end
    end

    context 'category_id validation' do
      it 'is invalid without category_id' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:category_id]).to include("can't be blank")
      end

      it 'is invalid with non-existent category_id' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: 99_999
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:category_id]).to include('Category does not exist')
      end
    end

    context 'specifications validation' do
      it 'is valid with valid JSON specifications' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id,
          specifications: '{"color": "black", "storage": "128GB"}'
        )
        expect(validator).to be_valid
      end

      it 'is invalid with invalid JSON specifications' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id,
          specifications: 'invalid json'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:specifications]).to include('Invalid JSON format')
      end

      it 'is valid with nil specifications' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id,
          specifications: nil
        )
        expect(validator).to be_valid
      end

      it 'is valid with empty string specifications' do
        validator = ProductValidator.new(
          name: 'iPhone 15',
          description: 'A product description',
          price: 999.99,
          stock_quantity: 10,
          brand_id: brand.id,
          category_id: category.id,
          specifications: ''
        )
        expect(validator).to be_valid
      end
    end
  end
end
