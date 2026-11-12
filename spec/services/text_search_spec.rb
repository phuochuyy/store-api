require 'rails_helper'

# Text search must behave the same on PostgreSQL and MySQL (CI runs the suite on both):
# matching is case-insensitive, and % or _ typed by a user is matched literally.
RSpec.describe 'Case-insensitive text search' do
  def names(rows)
    rows.map { |row| row[:name] || row['name'] }
  end

  describe Products::ProductService do
    let(:long_description) { 'This is a test product description that is long enough to meet validation requirements.' }
    let(:apple) { create(:brand, name: 'Apple') }
    let(:phones) { create(:category, name: 'Smartphones') }

    before do
      create(:product, name: 'iPhone 15 Pro', brand: apple, category: phones)
      create(:product, name: 'Galaxy S24', description: "#{long_description} Frame is 100% recycled.")
      create(:product, name: 'Pixel 9')
    end

    it 'list_products matches the name regardless of case' do
      expect(names(described_class.list_products(filters: { search: 'IPHONE' })[:products])).to eq(['iPhone 15 Pro'])
    end

    def search(term)
      names(described_class.search_products(filters: { search: term })[:products])
    end

    it 'search_products matches the name, description, brand or category' do
      expect(search('apple')).to eq(['iPhone 15 Pro'])
      expect(search('smartPHONES')).to eq(['iPhone 15 Pro'])
      expect(search('RECYCLED')).to eq(['Galaxy S24'])
    end

    it 'treats % and _ in the search term as plain characters' do
      expect(search('100%')).to eq(['Galaxy S24'])
      expect(described_class.list_products(filters: { search: '%' })[:products]).to be_empty
      expect(described_class.list_products(filters: { search: 'Pixel_' })[:products]).to be_empty
    end
  end

  describe Discounts::DiscountService do
    before do
      create(:discount, name: 'Summer SALE', code: 'SUMMER10')
      create(:discount, name: 'Winter deal', code: 'WINTER_5')
    end

    def discounts(filters)
      names(described_class.list_discounts(filters: filters)[:discounts])
    end

    it 'filters by name and code regardless of case' do
      expect(discounts(search: 'summer sale')).to eq(['Summer SALE'])
      expect(discounts(code: 'winter_')).to eq(['Winter deal'])
    end

    it 'does not treat % as a wildcard' do
      expect(discounts(search: '%')).to be_empty
    end
  end

  describe Discounts::PromotionService do
    before do
      Promotion.create!(name: 'Black Friday Bundle', promotion_type: 'bulk_pricing')
      Promotion.create!(name: 'Free gift with laptop', promotion_type: 'free_gift')
    end

    it 'filters by name regardless of case' do
      expect(names(described_class.list_promotions(filters: { search: 'BLACK friday' })[:promotions]))
        .to eq(['Black Friday Bundle'])
    end
  end
end
