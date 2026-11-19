require 'rails_helper'

# Two customers checking out the last items at the same moment must not both succeed.
# Each thread loads the record first and then all of them reduce stock together, which is
# exactly the interleaving a read-check-write implementation gets wrong (lost update / oversell).
RSpec.describe 'Stock reduction under concurrent checkouts', :concurrency do
  let(:initial_stock) { 3 }
  let(:threads) { 5 }

  def reduce_concurrently(model_class, record_id, threads:, quantity: 1)
    barrier = Concurrent::CyclicBarrier.new(threads)

    Array.new(threads) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          record = model_class.find(record_id)
          barrier.wait
          record.reduce_stock(quantity, reason: 'concurrency spec')
        end
      end
    end.map(&:value)
  end

  shared_examples 'an atomic stock reduction' do
    it 'never sells more than the available stock' do
      results = reduce_concurrently(described_class, record.id, threads: threads)

      expect(results.count(true)).to eq(initial_stock)
      expect(results.count(false)).to eq(threads - initial_stock)
      expect(record.reload.stock_quantity).to eq(0)
    end
  end

  describe Product do
    let(:record) { create(:product, stock_quantity: initial_stock) }

    it_behaves_like 'an atomic stock reduction'

    it 'records one stock movement per successful reduction' do
      reduce_concurrently(Product, record.id, threads: threads)

      expect(StockMovement.where(product_id: record.id).count).to eq(initial_stock)
    end
  end

  describe ProductVariant do
    let(:record) { create(:product_variant, stock_quantity: initial_stock) }

    it_behaves_like 'an atomic stock reduction'
  end
end
