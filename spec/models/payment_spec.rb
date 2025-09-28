# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      payment = build(:payment)
      expect(payment).to be_valid
    end

    it 'is invalid without an amount' do
      payment = build(:payment, amount: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include("can't be blank")
    end

    it 'is invalid with zero amount' do
      payment = build(:payment, amount: 0)
      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include('must be greater than 0')
    end

    it 'is invalid with negative amount' do
      payment = build(:payment, amount: -1)
      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include('must be greater than 0')
    end

    it 'sets default status when nil' do
      payment = build(:payment, status: nil)
      payment.valid?
      expect(payment.status).to eq('pending')
    end

    it 'sets default currency when nil' do
      payment = build(:payment, currency: nil)
      payment.valid?
      expect(payment.currency).to eq('USD')
    end

    it 'is invalid with duplicate transaction_id' do
      create(:payment, transaction_id: 'unique_id')
      payment = build(:payment, transaction_id: 'unique_id')
      expect(payment).not_to be_valid
      expect(payment.errors[:transaction_id]).to include('has already been taken')
    end

    it 'allows nil transaction_id' do
      payment = build(:payment, transaction_id: nil)
      expect(payment).to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum correctly' do
      expect(Payment.statuses).to eq({
                                       'pending' => 'pending',
                                       'processing' => 'processing',
                                       'completed' => 'completed',
                                       'failed' => 'failed',
                                       'cancelled' => 'cancelled',
                                       'refunded' => 'refunded',
                                       'partially_refunded' => 'partially_refunded'
                                     })
    end
  end

  describe 'scopes' do
    let!(:completed_payment) { create(:payment, status: 'completed') }
    let!(:failed_payment) { create(:payment, status: 'failed') }
    let!(:pending_payment) { create(:payment, status: 'pending') }
    let!(:refunded_payment) { create(:payment, status: 'refunded') }

    describe '.recent' do
      it 'orders payments by created_at desc' do
        expect(Payment.recent.first).to eq(refunded_payment)
      end
    end

    describe '.successful' do
      it 'returns only completed payments' do
        expect(Payment.successful).to include(completed_payment)
        expect(Payment.successful).not_to include(failed_payment, pending_payment)
      end
    end

    describe '.failed' do
      it 'returns failed and cancelled payments' do
        cancelled_payment = create(:payment, status: 'cancelled')
        expect(Payment.failed).to include(failed_payment, cancelled_payment)
        expect(Payment.failed).not_to include(completed_payment, pending_payment)
      end
    end

    describe '.refundable' do
      it 'returns only completed payments' do
        expect(Payment.refundable).to include(completed_payment)
        expect(Payment.refundable).not_to include(failed_payment, pending_payment, refunded_payment)
      end
    end

    describe '.by_status' do
      it 'filters payments by status' do
        expect(Payment.by_status('completed')).to include(completed_payment)
        expect(Payment.by_status('completed')).not_to include(failed_payment)
      end
    end
  end

  describe 'callbacks' do
    let(:order) { create(:order, status: 'pending') }
    let(:payment_method) { create(:payment_method) }

    it 'sets default values before validation' do
      payment = Payment.new(order: order, payment_method: payment_method, amount: 100)
      payment.valid?
      expect(payment.currency).to eq('USD')
      expect(payment.status).to eq('pending')
    end

    it 'updates order status when payment is completed' do
      payment = create(:payment, order: order, payment_method: payment_method, status: 'pending')
      payment.update!(status: 'completed')
      expect(order.reload.status).to eq('paid')
    end

    it 'updates order status when payment fails' do
      payment = create(:payment, order: order, payment_method: payment_method, status: 'pending')
      payment.update!(status: 'failed')
      expect(order.reload.status).to eq('payment_failed')
    end

    it 'updates order status when payment is refunded' do
      order.update!(status: 'paid')
      payment = create(:payment, order: order, payment_method: payment_method, status: 'completed')
      payment.update!(status: 'refunded')
      expect(order.reload.status).to eq('refunded')
    end
  end

  describe 'methods' do
    let(:payment_method) { create(:payment_method, processing_fee_percentage: 2.9, processing_fee_fixed: 0.30) }
    let(:payment) { create(:payment, payment_method: payment_method, amount: 100.0) }

    describe '#processing_fee' do
      it 'calculates processing fee from payment method' do
        expected_fee = payment_method.calculate_processing_fee(payment.amount)
        expect(payment.processing_fee).to eq(expected_fee)
      end
    end

    describe '#total_amount' do
      it 'calculates total amount including processing fee' do
        expected_total = payment.amount + payment.processing_fee
        expect(payment.total_amount).to eq(expected_total)
      end
    end

    describe '#successful?' do
      it 'returns true for completed payments' do
        payment.update!(status: 'completed')
        expect(payment.successful?).to be true
      end

      it 'returns false for non-completed payments' do
        payment.update!(status: 'failed')
        expect(payment.successful?).to be false
      end
    end

    describe '#failed?' do
      it 'returns true for failed payments' do
        payment.update!(status: 'failed')
        expect(payment.failed?).to be true
      end

      it 'returns true for cancelled payments' do
        payment.update!(status: 'cancelled')
        expect(payment.failed?).to be true
      end

      it 'returns false for successful payments' do
        payment.update!(status: 'completed')
        expect(payment.failed?).to be false
      end
    end

    describe '#refundable?' do
      it 'returns true for completed payments with refundable payment method' do
        payment.update!(status: 'completed')
        expect(payment.refundable?).to be true
      end

      it 'returns false for non-completed payments' do
        payment.update!(status: 'failed')
        expect(payment.refundable?).to be false
      end

      it 'returns false for non-refundable payment methods' do
        non_refundable_method = create(:payment_method, gateway_type: 'cash_on_delivery')
        payment.update!(payment_method: non_refundable_method, status: 'completed')
        expect(payment.refundable?).to be false
      end
    end

    describe '#can_be_refunded?' do
      it 'returns true for refundable or partially refundable payments' do
        payment.update!(status: 'completed')
        expect(payment.can_be_refunded?).to be true
      end

      it 'returns false for non-refundable payments' do
        payment.update!(status: 'failed')
        expect(payment.can_be_refunded?).to be false
      end
    end

    describe 'status update methods' do
      it 'marks payment as processing' do
        payment.mark_as_processing!
        expect(payment.status).to eq('processing')
      end

      it 'marks payment as completed' do
        payment.mark_as_completed!(transaction_id: 'test_id', gateway_response: '{"status": "success"}')
        expect(payment.status).to eq('completed')
        expect(payment.transaction_id).to eq('test_id')
        expect(payment.gateway_response).to eq('{"status": "success"}')
        expect(payment.processed_at).to be_present
      end

      it 'marks payment as failed' do
        payment.mark_as_failed!(reason: 'Insufficient funds', gateway_response: '{"error": "declined"}')
        expect(payment.status).to eq('failed')
        expect(payment.failure_reason).to eq('Insufficient funds')
        expect(payment.gateway_response).to eq('{"error": "declined"}')
        expect(payment.processed_at).to be_present
      end

      it 'marks payment as cancelled' do
        payment.mark_as_cancelled!(reason: 'User cancelled')
        expect(payment.status).to eq('cancelled')
        expect(payment.failure_reason).to eq('User cancelled')
        expect(payment.processed_at).to be_present
      end

      it 'marks payment as refunded' do
        payment.mark_as_refunded!(gateway_response: '{"refund_id": "re_123"}')
        expect(payment.status).to eq('refunded')
        expect(payment.gateway_response).to eq('{"refund_id": "re_123"}')
        expect(payment.processed_at).to be_present
      end

      it 'marks payment as partially refunded' do
        payment.mark_as_partially_refunded!(gateway_response: '{"refund_id": "re_123"}')
        expect(payment.status).to eq('partially_refunded')
        expect(payment.gateway_response).to eq('{"refund_id": "re_123"}')
        expect(payment.processed_at).to be_present
      end
    end

    describe '#processing_time' do
      it 'returns processing time when processed_at is present' do
        payment.update!(processed_at: 1.hour.from_now)
        expect(payment.processing_time).to be_present
      end

      it 'returns nil when processed_at is not present' do
        expect(payment.processing_time).to be_nil
      end
    end

    describe '#gateway_data' do
      it 'parses gateway_response JSON' do
        payment.update!(gateway_response: '{"status": "success", "id": "pi_123"}')
        expect(payment.gateway_data).to eq({ 'status' => 'success', 'id' => 'pi_123' })
      end

      it 'returns empty hash for invalid JSON' do
        payment.update!(gateway_response: 'invalid json')
        expect(payment.gateway_data).to eq({})
      end

      it 'returns empty hash for nil gateway_response' do
        expect(payment.gateway_data).to eq({})
      end
    end

    describe '#metadata_data' do
      it 'returns metadata hash' do
        payment.update!(metadata: { 'key' => 'value' })
        expect(payment.metadata_data).to eq({ 'key' => 'value' })
      end

      it 'returns empty hash for nil metadata' do
        expect(payment.metadata_data).to eq({})
      end
    end
  end

  describe 'associations' do
    it 'belongs to an order' do
      order = create(:order)
      payment = create(:payment, order: order)
      expect(payment.order).to eq(order)
    end

    it 'belongs to a payment method' do
      payment_method = create(:payment_method)
      payment = create(:payment, payment_method: payment_method)
      expect(payment.payment_method).to eq(payment_method)
    end
  end
end
