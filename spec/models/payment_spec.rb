require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:order) { create(:order) }
  let(:payment_method) { create(:payment_method) }
  let(:payment) { create(:payment, order: order, payment_method: payment_method) }

  describe 'associations' do
    it { should belong_to(:order) }
    it { should belong_to(:payment_method) }
    it { should have_many(:payment_histories).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:payment, order: order, payment_method: payment_method) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:currency) }
    it { should validate_uniqueness_of(:transaction_id).allow_nil }
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Payment.statuses.keys).to include('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded')
    end
  end

  describe 'scopes' do
    let!(:completed_payment) { create(:payment, :completed, order: order, payment_method: payment_method) }
    let!(:failed_payment) { create(:payment, :failed, order: order, payment_method: payment_method) }
    let!(:pending_payment) { create(:payment, order: order, payment_method: payment_method) }

    describe '.successful' do
      it 'returns only completed payments' do
        expect(Payment.successful).to include(completed_payment)
        expect(Payment.successful).not_to include(failed_payment, pending_payment)
      end
    end

    describe '.refundable' do
      it 'returns successful payments' do
        expect(Payment.refundable).to include(completed_payment)
      end
    end
  end

  describe '#processing_fee' do
    it 'delegates to payment_method' do
      allow(payment_method).to receive(:calculate_processing_fee).and_return(2.5)
      expect(payment.processing_fee).to eq(2.5)
    end
  end

  describe '#total_amount' do
    it 'returns amount plus processing fee' do
      allow(payment_method).to receive(:calculate_processing_fee).and_return(2.5)
      payment.update!(amount: 100.00)
      expect(payment.total_amount).to eq(102.5)
    end
  end

  describe '#successful?' do
    it 'returns true when status is completed' do
      payment.update!(status: 'completed')
      expect(payment.successful?).to be true
    end

    it 'returns false for other statuses' do
      payment.update!(status: 'pending')
      expect(payment.successful?).to be false
    end
  end

  describe '#failed?' do
    it 'returns true when status is failed or cancelled' do
      payment.update!(status: 'failed')
      expect(payment.failed?).to be true
      payment.update!(status: 'cancelled')
      expect(payment.failed?).to be true
    end

    it 'returns false for other statuses' do
      payment.update!(status: 'completed')
      expect(payment.failed?).to be false
    end
  end

  describe '#refundable?' do
    it 'returns true when payment is completed and method supports refunds' do
      payment.update!(status: 'completed')
      allow(payment_method).to receive(:supports_refunds?).and_return(true)
      expect(payment.refundable?).to be true
    end

    it 'returns false when payment is not completed' do
      payment.update!(status: 'pending')
      expect(payment.refundable?).to be false
    end
  end

  describe '#partially_refundable?' do
    it 'returns true when payment is completed and method supports partial refunds' do
      payment.update!(status: 'completed')
      allow(payment_method).to receive(:supports_partial_refunds?).and_return(true)
      expect(payment.partially_refundable?).to be true
    end
  end
end

