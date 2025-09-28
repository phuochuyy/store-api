require 'rails_helper'

RSpec.describe Phones::PhoneService, type: :service do
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:valid_phone_params) do
    {
      name: 'iPhone 15',
      description: 'Latest iPhone model',
      price: 999.99,
      stock_quantity: 10,
      brand_id: brand.id,
      category_id: category.id
    }
  end

  describe '.create_phone' do
    context 'with valid parameters' do
      it 'creates a new phone and returns success' do
        result = Phones::PhoneService.create_phone(valid_phone_params)

        expect(result[:phone]).to be_present
        expect(result[:phone][:name]).to eq('iPhone 15')
        expect(result[:phone][:price]).to eq(999.99)
        expect(result[:phone][:stock_quantity]).to eq(10)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing name' do
        invalid_params = valid_phone_params.merge(name: '')
        result = Phones::PhoneService.create_phone(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:errors]).to be_present
      end

      it 'returns error for negative price' do
        invalid_params = valid_phone_params.merge(price: -100)
        result = Phones::PhoneService.create_phone(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns error for negative stock quantity' do
        invalid_params = valid_phone_params.merge(stock_quantity: -5)
        result = Phones::PhoneService.create_phone(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns error for invalid brand_id' do
        invalid_params = valid_phone_params.merge(brand_id: 99_999)
        result = Phones::PhoneService.create_phone(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'returns error for invalid category_id' do
        invalid_params = valid_phone_params.merge(category_id: 99_999)
        result = Phones::PhoneService.create_phone(invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end
  end

  describe '.update_phone' do
    let(:phone) { create(:phone, brand: brand, category: category) }
    let(:update_params) do
      {
        name: 'Updated iPhone 15',
        price: 899.99,
        stock_quantity: 15
      }
    end

    context 'with valid parameters' do
      it 'updates the phone and returns success' do
        result = Phones::PhoneService.update_phone(phone.id, update_params)

        expect(result[:phone]).to be_present
        expect(phone.reload.name).to eq('Updated iPhone 15')
        expect(phone.reload.price).to eq(899.99)
        expect(phone.reload.stock_quantity).to eq(15)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid update data' do
        invalid_params = update_params.merge(price: -100)
        result = Phones::PhoneService.update_phone(phone.id, invalid_params)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'does not update the phone with invalid data' do
        original_name = phone.name
        invalid_params = update_params.merge(name: '')
        Phones::PhoneService.update_phone(phone.id, invalid_params)

        expect(phone.reload.name).to eq(original_name)
      end
    end
  end

  describe '.delete_phone' do
    let(:phone) { create(:phone, brand: brand, category: category) }

    context 'with valid phone' do
      it 'deletes the phone and returns success' do
        result = Phones::PhoneService.delete_phone(phone.id)

        expect(result[:success]).to be true
        expect(Phone.find_by(id: phone.id)).to be_nil
      end
    end

    context 'when phone has associated order items' do
      let(:order) { create(:order) }
      let!(:order_item) { create(:order_item, phone: phone, order: order) }

      it 'prevents deletion and returns error' do
        result = Phones::PhoneService.delete_phone(phone.id)

        expect(result[:success]).to be false
        expect(Phone.find_by(id: phone.id)).to be_present
      end
    end
  end

  describe '.search_phones' do
    let!(:phone1) { create(:phone, name: 'iPhone 15', brand: brand, category: category) }
    let!(:phone2) { create(:phone, name: 'Samsung Galaxy S24', brand: brand, category: category) }
    let!(:phone3) { create(:phone, name: 'Google Pixel 8', brand: brand, category: category) }

    context 'without search parameters' do
      it 'returns all phones' do
        result = Phones::PhoneService.list_phones(filters: {})

        expect(result[:phones].count).to eq(3)
      end
    end

    context 'with name search' do
      it 'returns phones matching name' do
        result = Phones::PhoneService.list_phones(filters: { search: 'iPhone' })

        expect(result[:phones].count).to eq(1)
        expect(result[:phones].first[:name]).to eq('iPhone 15')
      end
    end

    context 'with brand filter' do
      it 'returns phones from specific brand' do
        result = Phones::PhoneService.list_phones(filters: { brand_id: brand.id })

        expect(result[:phones].count).to eq(3)
      end
    end

    context 'with category filter' do
      it 'returns phones from specific category' do
        result = Phones::PhoneService.list_phones(filters: { category_id: category.id })

        expect(result[:phones].count).to eq(3)
      end
    end

    context 'with price range' do
      let!(:cheap_phone) { create(:phone, name: 'Cheap Phone', price: 100, brand: brand, category: category) }
      let!(:expensive_phone) { create(:phone, name: 'Expensive Phone', price: 2000, brand: brand, category: category) }

      it 'returns phones within price range' do
        result = Phones::PhoneService.list_phones(filters: { min_price: 500, max_price: 1500 })

        expect(result[:phones].count).to eq(2) # iPhone 15 and other phones in range
      end
    end

    context 'with stock filter' do
      let!(:out_of_stock_phone) do
        create(:phone, name: 'Out of Stock', stock_quantity: 0, brand: brand, category: category)
      end

      it 'returns only phones in stock' do
        result = Phones::PhoneService.list_phones(filters: { in_stock: true })

        expect(result[:phones].count).to eq(2) # Only phones in stock
        expect(result[:phones].map { |p| p[:name] }).not_to include('Out of Stock')
      end
    end

    context 'with pagination' do
      it 'returns paginated results' do
        result = Phones::PhoneService.list_phones(filters: {}, pagination: { page: 1, per_page: 2 })

        expect(result[:phones].count).to eq(2)
        expect(result[:pagination]).to be_present
      end
    end
  end
end
