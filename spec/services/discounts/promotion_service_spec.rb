require 'rails_helper'

RSpec.describe Discounts::PromotionService, '.apply_promotion_to_order' do
  let(:promotion) do
    Promotion.create!(name: 'Free shipping', promotion_type: 'shipping_discount', conditions: {},
                      benefits: { free_shipping: true }, usage_limit: 1)
  end

  def apply_to_new_order = described_class.apply_promotion_to_order(create(:order, :with_items), promotion.id)

  it 'counts a use for each order it is applied to' do
    expect(apply_to_new_order).to include(success: true)
    expect(promotion.reload.used_count).to eq(1)
  end

  it 'refuses the promotion once its usage limit is reached' do
    apply_to_new_order

    expect(apply_to_new_order).to include(success: false)
    expect(promotion.reload.used_count).to eq(1)
  end

  it 'gives the use back when applying the benefit fails' do
    allow(Discounts::PromotionBenefitService).to receive(:apply_promotion_benefit)
      .and_return({ success: false, error: 'Failed to apply promotion' })

    expect(apply_to_new_order).to include(success: false)
    expect(promotion.reload.used_count).to eq(0)
  end
end
