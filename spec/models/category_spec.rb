require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      category = build(:category)
      expect(category).to be_valid
    end

    it 'is invalid without a name' do
      category = build(:category, name: nil)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with name too short' do
      category = build(:category, name: 'A')
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include('is too short (minimum is 2 characters)')
    end

    it 'is invalid with name too long' do
      category = build(:category, name: 'A' * 51)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include('is too long (maximum is 50 characters)')
    end

    it 'is invalid with duplicate name' do
      create(:category, name: 'Smartphones')
      category = build(:category, name: 'Smartphones')
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include('has already been taken')
    end

    it 'is valid with unique name' do
      create(:category, name: 'Smartphones')
      category = build(:category, name: 'Tablets')
      expect(category).to be_valid
    end
  end

  describe 'associations' do
    let(:category) { create(:category) }

    it 'has many phones' do
      expect(category).to respond_to(:phones)
    end

    it 'destroys associated phones when destroyed' do
      phone = create(:phone, category: category)
      expect { category.destroy }.to change(Phone, :count).by(-1)
    end
  end

  describe 'scopes' do
    let!(:category1) { create(:category, name: 'Smartphones') }
    let!(:category2) { create(:category, name: 'Tablets') }

    it 'orders by name alphabetically' do
      categories = Category.all
      expect(categories.first).to eq(category1)
      expect(categories.last).to eq(category2)
    end
  end

  describe 'methods' do
    let(:category) { create(:category, name: 'Smartphones') }

    it 'has name attribute' do
      expect(category.name).to eq('Smartphones')
    end
  end
end
