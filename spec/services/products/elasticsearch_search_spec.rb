require 'rails_helper'

RSpec.describe Products::ProductService, '.search_products' do
  def names(result)
    result[:products].map { |product| product[:name] || product['name'] }
  end

  def search(filters, pagination = {})
    described_class.search_products(filters: filters, pagination: pagination)
  end

  let(:long_description) { 'A product description that is long enough to pass validation.' }
  let(:apple) { create(:brand, name: 'Apple') }
  let(:samsung) { create(:brand, name: 'Samsung') }
  let(:phones) { create(:category, name: 'Smartphones') }

  before do
    create(:product, name: 'iPhone 15 Pro', brand: apple, category: phones, price: 999, stock_quantity: 5)
    create(:product, name: 'Galaxy S24', brand: samsung, category: phones, price: 799, stock_quantity: 0)
    create(:product, name: 'Leather Case', brand: samsung, price: 39, stock_quantity: 50,
                     description: "Fits the Galaxy S24. #{long_description}")
  end

  # Runs against a real cluster: CI provides one, locally start it with
  # `docker compose --profile search up -d elasticsearch` and set ELASTICSEARCH_URL.
  context 'with Elasticsearch', :elasticsearch do
    before do
      skip 'Elasticsearch not configured (set ELASTICSEARCH_URL)' if ENV['ELASTICSEARCH_URL'].blank?
      allow(Search::Backend).to receive(:elasticsearch?).and_return(true)
      Product.reindex
      Product.search_index.refresh
    end

    it 'tolerates a typo' do
      expect(names(search(search: 'iphnoe'))).to eq(['iPhone 15 Pro'])
    end

    it 'ranks a match in the name above a match in the description' do
      expect(names(search(search: 'galaxy'))).to eq(['Galaxy S24', 'Leather Case'])
    end

    it 'combines the query with price and in-stock filters' do
      expect(names(search(search: 'samsung', max_price: '100', in_stock: 'true'))).to eq(['Leather Case'])
    end

    it 'returns the same pagination shape as the SQL search' do
      expect(search({ search: 'samsung' }, { page: 1, per_page: 1 })[:pagination])
        .to eq(current_page: 1, total_pages: 2, total_count: 2, per_page: 1)
    end

    it 'reindexes products when their brand is renamed' do
      apple.update!(name: 'Pear')
      Product.search_index.refresh

      expect(names(search(search: 'pear'))).to eq(['iPhone 15 Pro'])
    end
  end

  context 'when Elasticsearch is enabled but unreachable' do
    before do
      allow(Search::Backend).to receive(:elasticsearch?).and_return(true)
      allow(Product).to receive(:search).and_raise(Faraday::ConnectionFailed, 'connection refused')
    end

    it 'falls back to SQL search instead of failing the request' do
      expect(names(search(search: 'galaxy'))).to contain_exactly('Galaxy S24', 'Leather Case')
    end
  end

  context 'with the SQL backend' do
    it 'applies in_stock when it arrives as the string "true" from query params' do
      expect(names(search(search: 'samsung', in_stock: 'true'))).to eq(['Leather Case'])
    end
  end
end
