# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentHistory, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      payment_history = build(:payment_history)
      expect(payment_history).to be_valid
    end

    it 'is invalid without an action' do
      payment_history = build(:payment_history, action: nil)
      expect(payment_history).not_to be_valid
      expect(payment_history.errors[:action]).to include("can't be blank")
    end

    it 'sets default performed_at when nil' do
      payment_history = build(:payment_history, performed_at: nil)
      payment_history.valid?
      expect(payment_history.performed_at).to be_present
    end
  end

  describe 'enums' do
    it 'defines action enum correctly' do
      expect(PaymentHistory.actions).to eq({
                                             'created' => 'created',
                                             'status_changed' => 'status_changed',
                                             'amount_updated' => 'amount_updated',
                                             'transaction_updated' => 'transaction_updated',
                                             'refunded' => 'refunded',
                                             'failed' => 'failed',
                                             'cancelled' => 'cancelled',
                                             'processed' => 'processed',
                                             'gateway_response_updated' => 'gateway_response_updated',
                                             'metadata_updated' => 'metadata_updated'
                                           })
    end
  end

  describe 'scopes' do
    let!(:old_history) { create(:payment_history, performed_at: 1.day.ago) }
    let!(:recent_history) { create(:payment_history, performed_at: 1.hour.ago) }
    let!(:status_change_history) { create(:payment_history, :status_changed) }
    let!(:refund_history) { create(:payment_history, :refunded) }
    let!(:failure_history) { create(:payment_history, :failed) }
    let!(:admin_history) { create(:payment_history, :performed_by_admin) }

    describe '.recent' do
      it 'orders histories by performed_at desc' do
        recent_histories = PaymentHistory.recent.limit(2)
        expect(recent_histories.first.performed_at).to be > recent_histories.last.performed_at
      end
    end

    describe '.by_action' do
      it 'filters histories by action' do
        expect(PaymentHistory.by_action('status_changed')).to include(status_change_history)
        expect(PaymentHistory.by_action('status_changed')).not_to include(refund_history)
      end
    end

    describe '.by_performed_by' do
      it 'filters histories by performed_by' do
        expect(PaymentHistory.by_performed_by('admin@example.com')).to include(admin_history)
        expect(PaymentHistory.by_performed_by('admin@example.com')).not_to include(recent_history)
      end
    end

    describe '.status_changes' do
      it 'returns only status change histories' do
        expect(PaymentHistory.status_changes).to include(status_change_history)
        expect(PaymentHistory.status_changes).not_to include(refund_history, failure_history)
      end
    end

    describe '.refunds' do
      it 'returns only refund histories' do
        expect(PaymentHistory.refunds).to include(refund_history)
        expect(PaymentHistory.refunds).not_to include(status_change_history, failure_history)
      end
    end

    describe '.failures' do
      it 'returns only failure histories' do
        expect(PaymentHistory.failures).to include(failure_history)
        expect(PaymentHistory.failures).not_to include(status_change_history, refund_history)
      end
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      payment_history = PaymentHistory.new(payment: create(:payment), action: 'created')
      payment_history.valid?
      expect(payment_history.performed_at).to be_present
      expect(payment_history.performed_by).to eq('System')
    end
  end

  describe 'methods' do
    let(:payment_history) { create(:payment_history, :status_changed) }

    describe '#status_change?' do
      it 'returns true for status_changed action' do
        expect(payment_history.status_change?).to be true
      end

      it 'returns false for other actions' do
        refund_history = create(:payment_history, :refunded)
        expect(refund_history.status_change?).to be false
      end
    end

    describe '#status_transition' do
      it 'returns status transition for status changes' do
        expect(payment_history.status_transition).to eq('pending → completed')
      end

      it 'returns nil for non-status changes' do
        refund_history = create(:payment_history, :refunded)
        expect(refund_history.status_transition).to be_nil
      end
    end

    describe '#duration_since_previous' do
      it 'returns duration since previous history entry' do
        payment = create(:payment)
        first_time = 1.hour.ago
        second_time = Time.current

        first_history = create(:payment_history, payment: payment, performed_at: first_time)
        second_history = create(:payment_history, payment: payment, performed_at: second_time)

        # The duration should be a positive number (approximately 1 hour)
        expect(second_history.duration_since_previous).to be > 0
        expect(second_history.duration_since_previous).to be_a(Numeric)
      end

      it 'returns nil for first history entry' do
        payment = create(:payment)
        first_history = create(:payment_history, payment: payment, performed_at: 1.hour.ago)
        expect(first_history.duration_since_previous).to be_nil
      end

      it 'returns nil when no previous history exists' do
        payment = create(:payment)
        # Clear any existing histories for this payment
        payment.payment_histories.destroy_all
        history = create(:payment_history, payment: payment)
        expect(history.duration_since_previous).to be_nil
      end
    end

    describe '#gateway_data' do
      it 'parses gateway_response JSON' do
        payment_history.gateway_response = '{"status": "succeeded", "id": "pi_123"}'
        expect(payment_history.gateway_data).to eq({ 'status' => 'succeeded', 'id' => 'pi_123' })
      end

      it 'returns empty hash for invalid JSON' do
        payment_history.gateway_response = 'invalid json'
        expect(payment_history.gateway_data).to eq({})
      end

      it 'returns empty hash for nil gateway_response' do
        payment_history.gateway_response = nil
        expect(payment_history.gateway_data).to eq({})
      end
    end

    describe '#metadata_data' do
      it 'returns metadata hash' do
        payment_history.metadata = { 'key' => 'value' }
        expect(payment_history.metadata_data).to eq({ 'key' => 'value' })
      end

      it 'returns empty hash for nil metadata' do
        payment_history.metadata = nil
        expect(payment_history.metadata_data).to eq({})
      end
    end
  end

  describe 'class methods' do
    let(:payment) { create(:payment) }

    describe '.create_history_entry' do
      it 'creates a history entry with provided options' do
        history = PaymentHistory.create_history_entry(
          payment,
          'status_changed',
          previous_status: 'pending',
          new_status: 'completed',
          performed_by: 'admin@example.com',
          notes: 'Status updated manually'
        )

        expect(history).to be_persisted
        expect(history.payment).to eq(payment)
        expect(history.action).to eq('status_changed')
        expect(history.previous_status).to eq('pending')
        expect(history.new_status).to eq('completed')
        expect(history.performed_by).to eq('admin@example.com')
        expect(history.notes).to eq('Status updated manually')
      end
    end

    describe '.track_status_change' do
      it 'tracks status change' do
        history = PaymentHistory.track_status_change(
          payment,
          'pending',
          performed_by: 'admin@example.com',
          notes: 'Status changed'
        )

        expect(history.action).to eq('status_changed')
        expect(history.previous_status).to eq('pending')
        expect(history.new_status).to eq(payment.status)
        expect(history.performed_by).to eq('admin@example.com')
      end
    end

    describe '.track_refund' do
      it 'tracks refund' do
        history = PaymentHistory.track_refund(
          payment,
          50.00,
          performed_by: 'admin@example.com',
          notes: 'Partial refund'
        )

        expect(history.action).to eq('refunded')
        expect(history.amount).to eq(50.00)
        expect(history.performed_by).to eq('admin@example.com')
        expect(history.metadata['refund_amount']).to eq(50.00)
      end
    end

    describe '.get_payment_timeline' do
      it 'returns payment timeline' do
        # Clear existing histories for this payment
        payment.payment_histories.destroy_all

        create(:payment_history, payment: payment, action: 'created', performed_at: 1.hour.ago)
        create(:payment_history, payment: payment, action: 'status_changed', performed_at: 30.minutes.ago)

        timeline = PaymentHistory.get_payment_timeline(payment)

        expect(timeline.size).to eq(2)
        expect(timeline.first[:action]).to eq('created')
        expect(timeline.last[:action]).to eq('status_changed')
      end
    end

    describe '.get_payment_statistics' do
      it 'returns payment statistics' do
        # Use a specific date range to avoid interference from other tests
        start_date = 2.days.ago
        end_date = 1.day.ago

        create(:payment_history, :status_changed, performed_at: 1.5.days.ago)
        create(:payment_history, :refunded, performed_at: 1.5.days.ago)
        create(:payment_history, :failed, performed_at: 1.5.days.ago)

        stats = PaymentHistory.get_payment_statistics(start_date: start_date, end_date: end_date)

        expect(stats[:total_actions]).to eq(3)
        expect(stats[:actions_by_type]['status_changed']).to eq(1)
        expect(stats[:actions_by_type]['refunded']).to eq(1)
        expect(stats[:actions_by_type]['failed']).to eq(1)
        expect(stats[:status_changes]).to eq(1)
        expect(stats[:refunds]).to eq(1)
        expect(stats[:failures]).to eq(1)
      end
    end
  end

  describe 'associations' do
    it 'belongs to a payment' do
      payment = create(:payment)
      payment_history = create(:payment_history, payment: payment)
      expect(payment_history.payment).to eq(payment)
    end
  end
end
