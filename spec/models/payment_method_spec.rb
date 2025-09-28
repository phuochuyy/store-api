# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentMethod, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      payment_method = build(:payment_method)
      expect(payment_method).to be_valid
    end

    it 'is invalid without a name' do
      payment_method = build(:payment_method, name: nil)
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with duplicate name' do
      create(:payment_method, name: 'Test Payment Method')
      payment_method = build(:payment_method, name: 'Test Payment Method')
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:name]).to include('has already been taken')
    end

    it 'is invalid without gateway_type' do
      payment_method = build(:payment_method, gateway_type: nil)
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:gateway_type]).to include("can't be blank")
    end

    it 'is invalid with negative processing_fee_percentage' do
      payment_method = build(:payment_method, processing_fee_percentage: -1)
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:processing_fee_percentage]).to include('must be greater than or equal to 0')
    end

    it 'is invalid with processing_fee_percentage greater than 100' do
      payment_method = build(:payment_method, processing_fee_percentage: 101)
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:processing_fee_percentage]).to include('must be less than or equal to 100')
    end

    it 'is invalid with negative processing_fee_fixed' do
      payment_method = build(:payment_method, processing_fee_fixed: -1)
      expect(payment_method).not_to be_valid
      expect(payment_method.errors[:processing_fee_fixed]).to include('must be greater than or equal to 0')
    end
  end

  describe 'enums' do
    it 'defines gateway_type enum correctly' do
      expect(PaymentMethod.gateway_types).to eq({
                                                  'stripe' => 'stripe',
                                                  'paypal' => 'paypal',
                                                  'bank_transfer' => 'bank_transfer',
                                                  'cash_on_delivery' => 'cash_on_delivery',
                                                  'wallet' => 'wallet'
                                                })
    end
  end

  describe 'scopes' do
    let!(:active_payment_method) { create(:payment_method, is_active: true) }
    let!(:inactive_payment_method) { create(:payment_method, is_active: false) }
    let!(:stripe_payment_method) { create(:payment_method, gateway_type: 'stripe') }

    describe '.active' do
      it 'returns only active payment methods' do
        expect(PaymentMethod.active).to include(active_payment_method)
        expect(PaymentMethod.active).not_to include(inactive_payment_method)
      end
    end

    describe '.by_gateway_type' do
      it 'returns payment methods by gateway type' do
        expect(PaymentMethod.by_gateway_type('stripe')).to include(stripe_payment_method)
        expect(PaymentMethod.by_gateway_type('paypal')).not_to include(stripe_payment_method)
      end
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      payment_method = PaymentMethod.new(name: 'Test', gateway_type: 'stripe')
      payment_method.valid?
      expect(payment_method.processing_fee_percentage).to eq(0.0)
      expect(payment_method.processing_fee_fixed).to eq(0.0)
    end
  end

  describe 'methods' do
    let(:payment_method) { create(:payment_method, processing_fee_percentage: 2.9, processing_fee_fixed: 0.30) }

    describe '#calculate_processing_fee' do
      it 'calculates processing fee correctly' do
        amount = 100.0
        expected_fee = (100 * 2.9 / 100) + 0.30
        expect(payment_method.calculate_processing_fee(amount)).to eq(expected_fee.round(2))
      end

      it 'returns 0 for blank amount' do
        expect(payment_method.calculate_processing_fee(nil)).to eq(0)
        expect(payment_method.calculate_processing_fee(0)).to eq(0)
        expect(payment_method.calculate_processing_fee(-1)).to eq(0)
      end
    end

    describe '#total_amount_with_fees' do
      it 'calculates total amount with fees' do
        amount = 100.0
        expected_total = amount + payment_method.calculate_processing_fee(amount)
        expect(payment_method.total_amount_with_fees(amount)).to eq(expected_total.round(2))
      end
    end

    describe '#gateway_configured?' do
      it 'returns true when gateway_config is present and is a hash' do
        payment_method.gateway_config = { key: 'value' }
        expect(payment_method.gateway_configured?).to be true
      end

      it 'returns false when gateway_config is nil' do
        payment_method.gateway_config = nil
        expect(payment_method.gateway_configured?).to be false
      end

      it 'returns false when gateway_config is not a hash' do
        payment_method.gateway_config = 'string'
        expect(payment_method.gateway_configured?).to be false
      end
    end

    describe '#supports_refunds?' do
      it 'returns true for stripe and paypal' do
        stripe_method = create(:payment_method, gateway_type: 'stripe')
        paypal_method = create(:payment_method, gateway_type: 'paypal')

        expect(stripe_method.supports_refunds?).to be true
        expect(paypal_method.supports_refunds?).to be true
      end

      it 'returns false for other gateway types' do
        bank_method = create(:payment_method, gateway_type: 'bank_transfer')
        cod_method = create(:payment_method, gateway_type: 'cash_on_delivery')

        expect(bank_method.supports_refunds?).to be false
        expect(cod_method.supports_refunds?).to be false
      end
    end

    describe '#supports_partial_refunds?' do
      it 'returns true only for stripe' do
        stripe_method = create(:payment_method, gateway_type: 'stripe')
        paypal_method = create(:payment_method, gateway_type: 'paypal')

        expect(stripe_method.supports_partial_refunds?).to be true
        expect(paypal_method.supports_partial_refunds?).to be false
      end
    end
  end

  describe 'associations' do
    it 'has many payments' do
      payment_method = create(:payment_method)
      payment1 = create(:payment, payment_method: payment_method)
      payment2 = create(:payment, payment_method: payment_method)

      expect(payment_method.payments).to include(payment1, payment2)
    end

    it 'restricts deletion when payments exist' do
      payment_method = create(:payment_method)
      create(:payment, payment_method: payment_method)

      expect { payment_method.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
