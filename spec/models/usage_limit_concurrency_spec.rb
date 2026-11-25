require 'rails_helper'

# Several customers using the same limited code or promotion at the same moment. Each thread
# loads its record first and then all of them go together, which is exactly the interleaving a
# read-check-write counter gets wrong: every request sees a free use and the limit is overrun.
RSpec.describe 'Usage limits under concurrent requests', :concurrency do
  let(:usage_limit) { 3 }
  let(:threads) { 5 }

  def run_concurrently(ids)
    barrier = Concurrent::CyclicBarrier.new(ids.size)

    ids.map do |id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          prepared = yield(:load, id)
          barrier.wait
          yield(:run, prepared)
        end
      end
    end.map(&:value)
  end

  it 'never lets more orders than usage_limit hold a discount code' do
    discount = create(:discount, usage_limit: usage_limit)
    order_ids = Array.new(threads) { create(:order, :with_items).id }

    results = run_concurrently(order_ids) do |step, value|
      step == :load ? Order.find(value) : value.apply_discount(discount.code)[:success]
    end

    expect(results.count(true)).to eq(usage_limit)
    expect(discount.reload.used_count).to eq(usage_limit)
    expect(Order.where(discount_id: discount.id).count).to eq(usage_limit)
  end

  it 'never applies a promotion to more orders than usage_limit' do
    promotion = Promotion.create!(name: 'Free shipping', promotion_type: 'shipping_discount', conditions: {},
                                  benefits: { free_shipping: true }, usage_limit: usage_limit)
    order_ids = Array.new(threads) { create(:order, :with_items).id }

    results = run_concurrently(order_ids) do |step, value|
      if step == :load
        Order.find(value)
      else
        Discounts::PromotionService.apply_promotion_to_order(value, promotion.id)[:success]
      end
    end

    expect(results.count(true)).to eq(usage_limit)
    expect(promotion.reload.used_count).to eq(usage_limit)
  end
end
