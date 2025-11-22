require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Discount, type: :model do
  describe 'associations' do
    it { should have_many(:coupons).dependent(:destroy) }
    it { should have_many(:orders).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:discount) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_presence_of(:discount_type) }
    it { should validate_inclusion_of(:discount_type).in_array(%w[percentage fixed_amount free_shipping]) }
    it { should validate_presence_of(:value) }
    it { should validate_numericality_of(:value).is_greater_than_or_equal_to(0) }
    it { should validate_inclusion_of(:applies_to).in_array(%w[all products categories brands]) }
  end

  describe 'scopes' do
    let!(:active_discount) { create(:discount, is_active: true) }
    let!(:inactive_discount) { create(:discount, :inactive) }
    let!(:current_discount) { create(:discount, start_date: 1.day.ago, end_date: 1.day.from_now) }
    let!(:expired_discount) { create(:discount, :expired) }

    describe '.active' do
      it 'returns only active discounts' do
        expect(Discount.active).to include(active_discount)
        expect(Discount.active).not_to include(inactive_discount)
      end
    end

    describe '.current' do
      it 'returns only current discounts' do
        expect(Discount.current).to include(current_discount)
        expect(Discount.current).not_to include(expired_discount)
      end
    end

    describe '.available' do
      it 'returns active and current discounts' do
        expect(Discount.available).to include(active_discount, current_discount)
        expect(Discount.available).not_to include(inactive_discount, expired_discount)
      end
    end
  end

  describe '#available?' do
    it 'returns true when discount is active, current, and within usage limit' do
      discount = create(:discount, is_active: true, usage_limit: 10, used_count: 5)
      expect(discount.available?).to be true
    end

    it 'returns false when discount is inactive' do
      discount = create(:discount, :inactive)
      expect(discount.available?).to be false
    end

    it 'returns false when discount is expired' do
      discount = create(:discount, :expired)
      expect(discount.available?).to be false
    end

    it 'returns false when usage limit exceeded' do
      discount = create(:discount, usage_limit: 10, used_count: 10)
      expect(discount.available?).to be false
    end
  end

  describe '#calculate_discount' do
    context 'percentage discount' do
      it 'calculates percentage correctly' do
        discount = create(:discount, :percentage, value: 10)
        expect(discount.calculate_discount(100)).to eq(10.0)
      end

      it 'respects maximum_discount limit' do
        discount = create(:discount, :percentage, value: 50, maximum_discount: 20)
        expect(discount.calculate_discount(100)).to eq(20.0)
      end
    end

    context 'fixed_amount discount' do
      it 'calculates fixed amount correctly' do
        discount = create(:discount, :fixed_amount, value: 20)
        expect(discount.calculate_discount(100)).to eq(20.0)
      end

      it 'does not exceed order amount' do
        discount = create(:discount, :fixed_amount, value: 200)
        expect(discount.calculate_discount(100)).to eq(100.0)
      end
    end

    context 'free_shipping discount' do
      it 'returns 0 for free shipping' do
        discount = create(:discount, :free_shipping)
        expect(discount.calculate_discount(100)).to eq(0)
      end
    end
  end

  describe '#applies_to_items?' do
    let(:product1) { create(:product) }
    let(:product2) { create(:product) }
    let(:order_items) { [double(product: product1), double(product: product2)] }

    it 'returns true when applies_to is all' do
      discount = create(:discount, applies_to: 'all')
      expect(discount.applies_to_items?(order_items)).to be true
    end

    it 'checks product_ids when applies_to is products' do
      discount = create(:discount, applies_to: 'products', applies_to_ids: product1.id.to_s)
      expect(discount.applies_to_items?(order_items)).to be true
    end

    it 'checks category_ids when applies_to is categories' do
      discount = create(:discount, applies_to: 'categories', applies_to_ids: product1.category_id.to_s)
      expect(discount.applies_to_items?(order_items)).to be true
    end

    it 'checks brand_ids when applies_to is brands' do
      discount = create(:discount, applies_to: 'brands', applies_to_ids: product1.brand_id.to_s)
      expect(discount.applies_to_items?(order_items)).to be true
    end
  end

  describe '#meets_minimum_amount?' do
    it 'returns true when amount meets minimum' do
      discount = create(:discount, minimum_amount: 50)
      expect(discount.meets_minimum_amount?(100)).to be true
    end

    it 'returns false when amount is below minimum' do
      discount = create(:discount, minimum_amount: 50)
      expect(discount.meets_minimum_amount?(30)).to be false
    end

    it 'returns true when minimum_amount is nil' do
      discount = create(:discount, minimum_amount: nil)
      expect(discount.meets_minimum_amount?(10)).to be true
    end
  end

  describe '#increment_usage!' do
    it 'increments used_count' do
      discount = create(:discount, used_count: 5)
      discount.increment_usage!
      expect(discount.reload.used_count).to eq(6)
    end
  end

  describe '#decrement_usage!' do
    it 'decrements used_count' do
      discount = create(:discount, used_count: 5)
      discount.decrement_usage!
      expect(discount.reload.used_count).to eq(4)
    end

    it 'does not go below 0' do
      discount = create(:discount, used_count: 0)
      discount.decrement_usage!
      expect(discount.reload.used_count).to eq(0)
    end
  end

  describe 'callbacks' do
    describe 'before_validation :generate_code' do
      it 'generates code automatically on create' do
        discount = build(:discount, code: nil)
        discount.save!
        expect(discount.code).to be_present
        expect(discount.code).to start_with('DISC')
      end
    end

    describe 'before_validation :normalize_code' do
      it 'upcases code' do
        discount = create(:discount, code: 'test123')
        expect(discount.code).to eq('TEST123')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
