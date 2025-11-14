require 'rails_helper'

RSpec.describe Promotion, type: :model do
  describe 'validations' do
    subject { build(:promotion) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:promotion_type) }
    it { should validate_inclusion_of(:promotion_type).in_array(%w[bulk_pricing buy_x_get_y free_gift shipping_discount]) }
    it { should validate_inclusion_of(:priority).in_array(%w[high normal low]) }
  end

  describe 'scopes' do
    let!(:active_promotion) { create(:promotion, is_active: true) }
    let!(:inactive_promotion) { create(:promotion, :inactive) }

    describe '.active' do
      it 'returns only active promotions' do
        expect(Promotion.active).to include(active_promotion)
        expect(Promotion.active).not_to include(inactive_promotion)
      end
    end

    describe '.available' do
      it 'returns active and current promotions' do
        current = create(:promotion, start_date: 1.day.ago, end_date: 1.day.from_now)
        expect(Promotion.available).to include(current)
      end
    end
  end

  describe '#available?' do
    it 'returns true when promotion is active, current, and within usage limit' do
      promotion = create(:promotion, is_active: true, usage_limit: 10, used_count: 5)
      expect(promotion.available?).to be true
    end

    it 'returns false when promotion is inactive' do
      promotion = create(:promotion, :inactive)
      expect(promotion.available?).to be false
    end
  end

  describe '#increment_usage!' do
    it 'increments used_count' do
      promotion = create(:promotion, used_count: 5)
      promotion.increment_usage!
      expect(promotion.reload.used_count).to eq(6)
    end
  end
end

