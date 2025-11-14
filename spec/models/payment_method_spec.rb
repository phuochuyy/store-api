require 'rails_helper'

RSpec.describe PaymentMethod, type: :model do
  describe 'associations' do
    it { should have_many(:payments).dependent(:restrict_with_exception) }
  end

  describe 'validations' do
    subject { build(:payment_method) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:gateway_type) }
    it { should validate_presence_of(:processing_fee_percentage) }
    it { should validate_numericality_of(:processing_fee_percentage).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { should validate_presence_of(:processing_fee_fixed) }
    it { should validate_numericality_of(:processing_fee_fixed).is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it 'defines gateway_type enum' do
      expect(PaymentMethod.gateway_types.keys).to include('stripe', 'paypal', 'bank_transfer', 'cash_on_delivery', 'wallet')
    end
  end

  describe 'scopes' do
    let!(:active_method) { create(:payment_method, is_active: true) }
    let!(:inactive_method) { create(:payment_method, :inactive) }

    describe '.active' do
      it 'returns only active payment methods' do
        expect(PaymentMethod.active).to include(active_method)
        expect(PaymentMethod.active).not_to include(inactive_method)
      end
    end

    describe '.by_gateway_type' do
      it 'returns payment methods by gateway type' do
        stripe_method = create(:payment_method, gateway_type: 'stripe')
        expect(PaymentMethod.by_gateway_type('stripe')).to include(stripe_method)
      end
    end
  end

  describe '#calculate_processing_fee' do
    it 'calculates fee based on percentage and fixed amount' do
      method = create(:payment_method, processing_fee_percentage: 2.5, processing_fee_fixed: 1.0)
      expect(method.calculate_processing_fee(100)).to eq(3.5)
    end

    it 'returns 0 for invalid amount' do
      method = create(:payment_method)
      expect(method.calculate_processing_fee(0)).to eq(0)
      expect(method.calculate_processing_fee(-10)).to eq(0)
      expect(method.calculate_processing_fee(nil)).to eq(0)
    end
  end

  describe '#total_amount_with_fees' do
    it 'calculates total amount including fees' do
      method = create(:payment_method, processing_fee_percentage: 2.5, processing_fee_fixed: 1.0)
      expect(method.total_amount_with_fees(100)).to eq(103.5)
    end
  end

  describe '#gateway_configured?' do
    it 'returns true when gateway_config is present and is a hash' do
      method = create(:payment_method, gateway_config: { api_key: 'test' })
      expect(method.gateway_configured?).to be true
    end

    it 'returns false when gateway_config is nil' do
      method = create(:payment_method, gateway_config: nil)
      expect(method.gateway_configured?).to be false
    end
  end

  describe '#supports_refunds?' do
    it 'returns true for stripe and paypal' do
      stripe = create(:payment_method, gateway_type: 'stripe')
      paypal = create(:payment_method, :paypal)
      expect(stripe.supports_refunds?).to be true
      expect(paypal.supports_refunds?).to be true
    end

    it 'returns false for other gateway types' do
      bank = create(:payment_method, :bank_transfer)
      expect(bank.supports_refunds?).to be false
    end
  end

  describe '#supports_partial_refunds?' do
    it 'returns true only for stripe' do
      stripe = create(:payment_method, gateway_type: 'stripe')
      paypal = create(:payment_method, :paypal)
      expect(stripe.supports_partial_refunds?).to be true
      expect(paypal.supports_partial_refunds?).to be false
    end
  end
end

