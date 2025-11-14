require 'rails_helper'

RSpec.describe Coupon, type: :model do
  let(:discount) { create(:discount) }
  let(:user) { create(:user) }
  let(:order) { create(:order) }
  let(:coupon) { create(:coupon, discount: discount) }

  describe 'associations' do
    it { should belong_to(:discount) }
    it { should belong_to(:user).optional }
    it { should belong_to(:order).optional }
  end

  describe 'validations' do
    subject { build(:coupon, discount: discount) }

    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_inclusion_of(:status).in_array(%w[active used expired cancelled]) }
    it { should validate_numericality_of(:discount_amount).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:active_coupon) { create(:coupon, discount: discount, status: 'active') }
    let!(:used_coupon) { create(:coupon, :used, discount: discount) }
    let!(:expired_coupon) { create(:coupon, :expired, discount: discount) }

    describe '.active' do
      it 'returns only active coupons' do
        expect(Coupon.active).to include(active_coupon)
        expect(Coupon.active).not_to include(used_coupon, expired_coupon)
      end
    end

    describe '.available' do
      it 'returns active coupons not used' do
        expect(Coupon.available).to include(active_coupon)
        expect(Coupon.available).not_to include(used_coupon)
      end
    end
  end

  describe '#available?' do
    it 'returns true when coupon is active, not used, not expired, and discount is available' do
      expect(coupon.available?).to be true
    end

    it 'returns false when coupon is used' do
      used_coupon = create(:coupon, :used, discount: discount)
      expect(used_coupon.available?).to be false
    end

    it 'returns false when discount is not available' do
      inactive_discount = create(:discount, :inactive)
      coupon = create(:coupon, discount: inactive_discount)
      expect(coupon.available?).to be false
    end
  end

  describe '#used?' do
    it 'returns true when status is used' do
      used_coupon = create(:coupon, :used, discount: discount)
      expect(used_coupon.used?).to be true
    end

    it 'returns true when used_at is present' do
      coupon.update!(used_at: Time.current)
      expect(coupon.used?).to be true
    end
  end

  describe '#use!' do
    it 'marks coupon as used successfully' do
      result = coupon.use!(order, user)
      expect(result[:success]).to be true
      expect(coupon.reload.status).to eq('used')
      expect(coupon.used_at).to be_present
      expect(coupon.order).to eq(order)
      expect(coupon.user).to eq(user)
    end

    it 'calculates discount_amount from order total' do
      order.update!(total_amount: 100.00)
      discount.update!(discount_type: 'percentage', value: 10)
      result = coupon.use!(order)
      expect(coupon.reload.discount_amount).to eq(10.0)
    end

    it 'increments discount used_count' do
      expect { coupon.use!(order) }.to change { discount.reload.used_count }.by(1)
    end

    it 'returns error when coupon is not available' do
      used_coupon = create(:coupon, :used, discount: discount)
      result = used_coupon.use!(order)
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Coupon not available')
    end
  end

  describe '#cancel!' do
    it 'cancels coupon successfully' do
      result = coupon.cancel!
      expect(result[:success]).to be true
      expect(coupon.reload.status).to eq('cancelled')
    end

    it 'returns error when coupon is already used' do
      used_coupon = create(:coupon, :used, discount: discount)
      result = used_coupon.cancel!
      expect(result[:success]).to be false
    end
  end

  describe '#expire!' do
    it 'marks coupon as expired' do
      coupon.expire!
      expect(coupon.reload.status).to eq('expired')
    end
  end

  describe 'callbacks' do
    describe 'before_validation :generate_code' do
      it 'generates code automatically on create' do
        coupon = build(:coupon, discount: discount, code: nil)
        coupon.save!
        expect(coupon.code).to be_present
        expect(coupon.code).to start_with('COUPON')
      end
    end

    describe 'before_save :set_used_at_if_used' do
      it 'sets used_at when status changes to used' do
        coupon.update!(status: 'used')
        expect(coupon.used_at).to be_present
      end
    end
  end
end

