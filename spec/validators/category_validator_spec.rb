require 'rails_helper'

RSpec.describe CategoryValidator, type: :validator do
  describe 'validations' do
    context 'with valid attributes' do
      it 'is valid' do
        validator = CategoryValidator.new(
          name: 'Smartphones',
          description: 'Mobile phones and accessories'
        )
        expect(validator).to be_valid
      end
    end

    context 'name validation' do
      it 'is invalid without name' do
        validator = CategoryValidator.new(description: 'A category description')
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with name too short' do
        validator = CategoryValidator.new(name: 'A', description: 'A category description')
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too short (minimum is 2 characters)')
      end

      it 'is invalid with name too long' do
        validator = CategoryValidator.new(
          name: 'A' * 101,
          description: 'A category description'
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:name]).to include('is too long (maximum is 100 characters)')
      end

      it 'is valid with name at minimum length' do
        validator = CategoryValidator.new(
          name: 'AB',
          description: 'A category description'
        )
        expect(validator).to be_valid
      end

      it 'is valid with name at maximum length' do
        validator = CategoryValidator.new(
          name: 'A' * 100,
          description: 'A category description'
        )
        expect(validator).to be_valid
      end
    end

    context 'description validation' do
      it 'is invalid without description' do
        validator = CategoryValidator.new(name: 'Smartphones')
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include("can't be blank")
      end

      it 'is invalid with description too short' do
        validator = CategoryValidator.new(name: 'Smartphones', description: 'Short')
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too short (minimum is 10 characters)')
      end

      it 'is invalid with description too long' do
        validator = CategoryValidator.new(
          name: 'Smartphones',
          description: 'A' * 501
        )
        expect(validator).not_to be_valid
        expect(validator.errors[:description]).to include('is too long (maximum is 500 characters)')
      end

      it 'is valid with description at minimum length' do
        validator = CategoryValidator.new(
          name: 'Smartphones',
          description: 'A' * 10
        )
        expect(validator).to be_valid
      end

      it 'is valid with description at maximum length' do
        validator = CategoryValidator.new(
          name: 'Smartphones',
          description: 'A' * 500
        )
        expect(validator).to be_valid
      end
    end
  end

  describe 'attributes' do
    it 'has name attribute' do
      validator = CategoryValidator.new(name: 'Smartphones')
      expect(validator.name).to eq('Smartphones')
    end

    it 'has description attribute' do
      validator = CategoryValidator.new(description: 'A category')
      expect(validator.description).to eq('A category')
    end
  end
end
