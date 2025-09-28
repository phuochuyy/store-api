# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::PaymentProcessorService, type: :service do
  let(:order) { create(:order, total_amount: 100.0, status: 'pending') }
  let(:payment_method) { create(:payment_method, :stripe) }
  let(:payment_data) { { 'card_number' => '4242424242424242', 'cvv' => '123' } }

  describe '.process_payment' do
    context 'with valid parameters' do
      it 'processes payment successfully' do
        result = described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to be_present
        expect(result[:gateway_response]).to be_present
      end

      it 'creates a payment record' do
        expect do
          described_class.process_payment(
            order: order,
            payment_method: payment_method,
            payment_data: payment_data
          )
        end.to change(Payment, :count).by(1)
      end

      it 'marks payment as completed' do
        described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        payment = Payment.last
        expect(payment.status).to eq('completed')
        expect(payment.transaction_id).to be_present
        expect(payment.processed_at).to be_present
      end

      it 'updates order status to paid' do
        described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(order.reload.status).to eq('paid')
      end
    end

    context 'with invalid parameters' do
      it 'returns error when order is nil' do
        result = described_class.process_payment(
          order: nil,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order not found')
      end

      it 'returns error when payment method is nil' do
        result = described_class.process_payment(
          order: order,
          payment_method: nil,
          payment_data: payment_data
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment method not found')
      end

      it 'returns error when order cannot be paid' do
        order.update!(status: 'paid')

        result = described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Order cannot be paid')
      end

      it 'returns error when payment method is inactive' do
        payment_method.update!(is_active: false)

        result = described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment method is not active')
      end
    end

    context 'with different gateway types' do
      it 'processes stripe payment' do
        stripe_method = create(:payment_method, :stripe)

        result = described_class.process_payment(
          order: order,
          payment_method: stripe_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('stripe_')
      end

      it 'processes paypal payment' do
        paypal_method = create(:payment_method, :paypal)

        result = described_class.process_payment(
          order: order,
          payment_method: paypal_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('paypal_')
      end

      it 'processes bank transfer payment' do
        bank_method = create(:payment_method, :bank_transfer)

        result = described_class.process_payment(
          order: order,
          payment_method: bank_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('bank_')
      end

      it 'processes cash on delivery payment' do
        cod_method = create(:payment_method, :cash_on_delivery)

        result = described_class.process_payment(
          order: order,
          payment_method: cod_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('cod_')
      end

      it 'processes wallet payment' do
        wallet_method = create(:payment_method, :wallet)

        result = described_class.process_payment(
          order: order,
          payment_method: wallet_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('wallet_')
      end
    end

    context 'when processing fails' do
      it 'handles processing errors gracefully' do
        allow(Payment).to receive(:create!).and_raise(StandardError.new('Database error'))

        result = described_class.process_payment(
          order: order,
          payment_method: payment_method,
          payment_data: payment_data
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment processing failed')
        expect(result[:details]).to eq('Database error')
      end
    end
  end

  describe '.refund_payment' do
    let(:payment) { create(:payment, :completed, amount: 100.0) }

    context 'with valid parameters' do
      it 'processes full refund successfully' do
        result = described_class.refund_payment(payment: payment)

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to be_present
        expect(result[:gateway_response]).to be_present
      end

      it 'processes partial refund successfully' do
        result = described_class.refund_payment(payment: payment, amount: 50.0)

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to be_present
      end

      it 'marks payment as refunded for full refund' do
        described_class.refund_payment(payment: payment)

        expect(payment.reload.status).to eq('refunded')
      end

      it 'marks payment as partially refunded for partial refund' do
        described_class.refund_payment(payment: payment, amount: 50.0)

        expect(payment.reload.status).to eq('partially_refunded')
      end

      it 'updates order status to refunded' do
        order.update!(status: 'paid')
        payment.update!(order: order)

        described_class.refund_payment(payment: payment)

        expect(order.reload.status).to eq('refunded')
      end
    end

    context 'with invalid parameters' do
      it 'returns error when payment is nil' do
        result = described_class.refund_payment(payment: nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment not found')
      end

      it 'returns error when payment cannot be refunded' do
        payment.update!(status: 'failed')

        result = described_class.refund_payment(payment: payment)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment cannot be refunded')
      end

      it 'returns error when refund amount exceeds payment amount' do
        result = described_class.refund_payment(payment: payment, amount: 150.0)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Refund amount exceeds payment amount')
      end
    end

    context 'with different gateway types' do
      it 'processes stripe refund' do
        stripe_payment = create(:payment, :stripe_payment, :completed)

        result = described_class.refund_payment(payment: stripe_payment)

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('re_')
      end

      it 'processes paypal refund' do
        paypal_payment = create(:payment, :paypal_payment, :completed)

        result = described_class.refund_payment(payment: paypal_payment)

        expect(result[:success]).to be true
        expect(result[:transaction_id]).to start_with('refund_')
      end

      it 'returns error for non-refundable payment methods' do
        cod_payment = create(:payment, :cash_on_delivery_payment, :completed)

        result = described_class.refund_payment(payment: cod_payment)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Payment cannot be refunded')
      end
    end

    context 'when refund fails' do
      it 'handles refund errors gracefully' do
        allow(payment).to receive(:update!).and_raise(StandardError.new('Database error'))

        result = described_class.refund_payment(payment: payment)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Refund processing failed')
        expect(result[:details]).to eq('Database error')
      end
    end
  end
end
