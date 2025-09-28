require 'rails_helper'

RSpec.describe Categories::CategoryService, type: :service do
  let!(:category1) { create(:category, name: 'Smartphones') }
  let!(:category2) { create(:category, name: 'Tablets') }
  let!(:category3) { create(:category, name: 'Accessories') }

  describe '.list_categories' do
    context 'without pagination' do
      it 'returns all categories with default pagination' do
        result = Categories::CategoryService.list_categories

        expect(result[:categories]).to be_an(Array)
        expect(result[:categories].length).to eq(3)
        expect(result[:pagination]).to be_present
        expect(result[:pagination][:current_page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(10)
      end
    end

    context 'with pagination' do
      it 'returns paginated categories' do
        result = Categories::CategoryService.list_categories(pagination: { page: 1, per_page: 2 })

        expect(result[:categories].length).to eq(2)
        expect(result[:pagination][:current_page]).to eq(1)
        expect(result[:pagination][:per_page]).to eq(2)
        expect(result[:pagination][:total_pages]).to eq(2)
      end

      it 'returns second page of categories' do
        result = Categories::CategoryService.list_categories(pagination: { page: 2, per_page: 2 })

        expect(result[:categories].length).to eq(1)
        expect(result[:pagination][:current_page]).to eq(2)
      end
    end

    it 'includes phones count in category data' do
      create(:phone, category: category1)
      result = Categories::CategoryService.list_categories

      category_data = result[:categories].find { |c| c[:id] == category1.id }
      expect(category_data).to be_present
    end
  end

  describe '.find_category' do
    context 'with valid category id' do
      it 'returns category details' do
        result = Categories::CategoryService.find_category(category1.id)

        expect(result[:category]).to be_present
        expect(result[:category][:id]).to eq(category1.id)
        expect(result[:category][:name]).to eq('Smartphones')
        expect(result[:phones_count]).to eq(0)
      end

      it 'includes phones count' do
        create(:phone, category: category1)
        result = Categories::CategoryService.find_category(category1.id)

        expect(result[:phones_count]).to eq(1)
      end
    end

    context 'with invalid category id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Categories::CategoryService.find_category(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.create_category' do
    let(:valid_params) { { name: 'New Category', description: 'A new category' } }

    context 'with valid parameters' do
      it 'creates a new category' do
        expect do
          result = Categories::CategoryService.create_category(valid_params)
          expect(result[:success]).to be true
          expect(result[:category]).to be_present
          expect(result[:category][:name]).to eq('New Category')
        end.to change(Category, :count).by(1)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing name' do
        invalid_params = { description: 'A category without name' }
        result = Categories::CategoryService.create_category(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Name can't be blank")
      end

      it 'returns error for duplicate name' do
        invalid_params = { name: 'Smartphones', description: 'Duplicate name' }
        result = Categories::CategoryService.create_category(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Name has already been taken')
      end

      it 'returns error for name too short' do
        invalid_params = { name: 'A', description: 'Too short' }
        result = Categories::CategoryService.create_category(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Name is too short (minimum is 2 characters)')
      end
    end
  end

  describe '.update_category' do
    let(:update_params) { { name: 'Updated Category', description: 'Updated description' } }

    context 'with valid parameters' do
      it 'updates the category' do
        result = Categories::CategoryService.update_category(category1.id, update_params)

        expect(result[:success]).to be true
        expect(result[:category][:name]).to eq('Updated Category')
        expect(result[:category][:description]).to eq('Updated description')

        category1.reload
        expect(category1.name).to eq('Updated Category')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid data' do
        invalid_params = { name: '', description: 'Invalid name' }
        result = Categories::CategoryService.update_category(category1.id, invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Name can't be blank")
      end

      it 'does not update the category with invalid data' do
        original_name = category1.name
        invalid_params = { name: '', description: 'Invalid name' }
        Categories::CategoryService.update_category(category1.id, invalid_params)

        expect(category1.reload.name).to eq(original_name)
      end
    end

    context 'with invalid category id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Categories::CategoryService.update_category(99_999, update_params)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.delete_category' do
    context 'with valid category id' do
      it 'deletes the category' do
        expect do
          result = Categories::CategoryService.delete_category(category1.id)
          expect(result[:success]).to be true
        end.to change(Category, :count).by(-1)
      end
    end

    context 'with invalid category id' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Categories::CategoryService.delete_category(99_999)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when category has associated phones' do
      let!(:phone) { create(:phone, category: category1) }

      it 'deletes the category and associated phones' do
        expect do
          result = Categories::CategoryService.delete_category(category1.id)
          expect(result[:success]).to be true
        end.to change(Category, :count).by(-1)
                                       .and change(Phone, :count).by(-1)
      end
    end
  end
end
