require 'rails_helper'

RSpec.describe BrandValidator, type: :validator do
  describe 'validations' do
    context 'with valid attributes' do
      it 'is valid' do
        validator = BrandValidator.new(
          name: 'Apple',
          description: 'A premium technology brand'
        )
        expect(validator).to be_valid
      end
    end

    context 'name validation' do
      it 'is invalid without name' do
        validator = BrandValidator.new(description: 'A brand description')
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with name too short' do
        validator = BrandValidator.new(name: 'A', description: 'A brand description')
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too short (minimum is 2 characters)')
      end

      it 'is invalid with name too long' do
        validator = BrandValidator.new(
          name: 'A' * 101,
          description: 'A brand description'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too long (maximum is 100 characters)')
      end

      it 'is valid with name at minimum length' do
        validator = BrandValidator.new(
          name: 'AB',
          description: 'A brand description'
        )
        expect(validator).to be_valid
      end

      it 'is valid with name at maximum length' do
        validator = BrandValidator.new(
          name: 'A' * 100,
          description: 'A brand description'
        )
        expect(validator).to be_valid
      end
    end

    context 'description validation' do
      it 'is invalid without description' do
        validator = BrandValidator.new(name: 'Apple')
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include("can't be blank")
      end

      it 'is invalid with description too short' do
        validator = BrandValidator.new(name: 'Apple', description: 'Short')
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too short (minimum is 10 characters)')
      end

      it 'is invalid with description too long' do
        validator = BrandValidator.new(
          name: 'Apple',
          description: 'A' * 501
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too long (maximum is 500 characters)')
      end

      it 'is valid with description at minimum length' do
        validator = BrandValidator.new(
          name: 'Apple',
          description: 'A' * 10
        )
        expect(validator).to be_valid
      end

      it 'is valid with description at maximum length' do
        validator = BrandValidator.new(
          name: 'Apple',
          description: 'A' * 500
        )
        expect(validator).to be_valid
      end
    end
  end

  describe 'attributes' do
    it 'has name attribute' do
      validator = BrandValidator.new(name: 'Apple')
      expect(validator.name).to eq('Apple')
    end

    it 'has description attribute' do
      validator = BrandValidator.new(description: 'A brand')
      expect(validator.description).to eq('A brand')
    end
  end
end
