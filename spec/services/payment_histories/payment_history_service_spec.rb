# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentHistories::PaymentHistoryService, type: :service do
  let(:user) { create(:user, role: 'customer') }
  let(:order) { create(:order, user: user) }
  let(:payment_method) { create(:payment_method) }
  let(:payment) { create(:payment, order: order, payment_method: payment_method) }

  describe '.get_histories' do
    let!(:history1) { create(:payment_history, payment: payment, action: 'created', performed_at: 1.day.ago) }
    let!(:history2) { create(:payment_history, payment: payment, action: 'status_changed', performed_at: 2.days.ago) }
    let!(:history3) { create(:payment_history, payment: payment, action: 'refunded', performed_at: 3.days.ago) }

    it 'returns all histories when no filters applied' do
      histories = described_class.get_histories
      expect(histories.count).to eq(3)
    end

    it 'filters by payment_id' do
      other_payment = create(:payment, order: order, payment_method: payment_method)
      create(:payment_history, payment: other_payment)

      histories = described_class.get_histories(payment_id: payment.id)
      expect(histories.count).to eq(3)
    end

    it 'filters by action' do
      histories = described_class.get_histories(action: 'created')
      expect(histories.count).to eq(1)
      expect(histories.first.action).to eq('created')
    end

    it 'filters by performed_by' do
      create(:payment_history, payment: payment, performed_by: 'admin@example.com')

      histories = described_class.get_histories(performed_by: 'admin@example.com')
      expect(histories.count).to eq(1)
      expect(histories.first.performed_by).to eq('admin@example.com')
    end

    it 'filters by date range' do
      histories = described_class.get_histories(
        start_date: 1.5.days.ago,
        end_date: Time.current
      )
      expect(histories.count).to eq(1)
      expect(histories.first).to eq(history1)
    end

    it 'filters by status_changes' do
      histories = described_class.get_histories(status_changes: true)
      expect(histories.count).to eq(1)
      expect(histories.first.action).to eq('status_changed')
    end

    it 'filters by refunds' do
      histories = described_class.get_histories(refunds: true)
      expect(histories.count).to eq(1)
      expect(histories.first.action).to eq('refunded')
    end

    it 'filters by failures' do
      create(:payment_history, payment: payment, action: 'failed')

      histories = described_class.get_histories(failures: true)
      expect(histories.count).to eq(1)
      expect(histories.first.action).to eq('failed')
    end

    it 'filters by user_id' do
      other_user = create(:user, role: 'customer')
      other_order = create(:order, user: other_user)
      other_payment = create(:payment, order: other_order, payment_method: payment_method)
      create(:payment_history, payment: other_payment)

      histories = described_class.get_histories(user_id: user.id)
      expect(histories.count).to eq(3)
    end

    it 'orders by performed_at desc' do
      histories = described_class.get_histories
      expect(histories.first).to eq(history1)
      expect(histories.last).to eq(history3)
    end
  end

  describe '.get_payment_timeline' do
    let!(:history1) { create(:payment_history, payment: payment, action: 'created', performed_at: 1.hour.ago) }
    let!(:history2) do
      create(:payment_history, payment: payment, action: 'status_changed', performed_at: 30.minutes.ago)
    end
    let!(:history3) { create(:payment_history, payment: payment, action: 'processed', performed_at: Time.current) }

    it 'returns chronological timeline' do
      timeline = described_class.get_payment_timeline(payment)

      expect(timeline).to be_an(Array)
      expect(timeline.length).to eq(3)
      expect(timeline.first['action']).to eq('created')
      expect(timeline.last['action']).to eq('processed')
    end

    it 'includes all required fields' do
      timeline = described_class.get_payment_timeline(payment)
      entry = timeline.first

      expect(entry).to have_key('id')
      expect(entry).to have_key('action')
      expect(entry).to have_key('description')
      expect(entry).to have_key('performed_by')
      expect(entry).to have_key('performed_at')
    end
  end

  describe '.get_audit_trail_details' do
    let(:payment_history) { create(:payment_history, payment: payment) }

    it 'returns audit trail details' do
      audit_data = described_class.get_audit_trail_details(payment_history)

      expect(audit_data[:success]).to be true
      expect(audit_data[:id]).to eq(payment_history.id)
      expect(audit_data[:payment_id]).to eq(payment_history.payment_id)
      expect(audit_data[:action]).to eq(payment_history.action)
    end

    it 'handles non-existent payment history' do
      audit_data = described_class.get_audit_trail_details(nil)

      expect(audit_data[:success]).to be false
      expect(audit_data[:error]).to eq('Payment history entry not found')
    end
  end

  describe '.get_statistics' do
    let!(:history1) { create(:payment_history, payment: payment, action: 'created', performed_at: 1.day.ago) }
    let!(:history2) { create(:payment_history, payment: payment, action: 'status_changed', performed_at: 1.day.ago) }
    let!(:history3) { create(:payment_history, payment: payment, action: 'refunded', performed_at: 2.days.ago) }

    it 'returns comprehensive statistics' do
      stats = described_class.get_statistics

      expect(stats[:success]).to be true
      expect(stats[:total_actions]).to eq(3)
      expect(stats[:actions_by_type]).to include('created' => 1, 'status_changed' => 1, 'refunded' => 1)
      expect(stats[:status_changes]).to eq(1)
      expect(stats[:refunds]).to eq(1)
    end

    it 'filters statistics by date range' do
      stats = described_class.get_statistics(
        start_date: 1.5.days.ago,
        end_date: Time.current
      )

      expect(stats[:total_actions]).to eq(2)
    end

    it 'includes failure analysis' do
      create(:payment_history, payment: payment, action: 'failed', notes: 'Insufficient funds')

      stats = described_class.get_statistics

      expect(stats[:failure_analysis]).to have_key('total_failures')
      expect(stats[:failure_analysis]).to have_key('failure_rate')
      expect(stats[:failure_analysis]).to have_key('common_failure_reasons')
    end
  end

  describe '.export_history' do
    let!(:history) { create(:payment_history, payment: payment) }

    it 'exports data in CSV format' do
      exported_data = described_class.export_history(format: 'csv')

      expect(exported_data).to be_a(String)
      expect(exported_data).to include('ID,PaymentID,OrderID,Action')
      expect(exported_data).to include(history.id.to_s)
    end

    it 'exports data in JSON format' do
      exported_data = described_class.export_history(format: 'json')

      expect(exported_data).to be_a(String)
      parsed_data = JSON.parse(exported_data)
      expect(parsed_data).to be_an(Array)
    end

    it 'handles unsupported format' do
      result = described_class.export_history(format: 'xml')

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Unsupported export format')
    end

    it 'applies filters to export' do
      create(:payment_history, payment: payment, action: 'created')
      create(:payment_history, payment: payment, action: 'status_changed')

      exported_data = described_class.export_history(
        format: 'csv',
        filters: { action: 'created' }
      )

      lines = exported_data.split("\n")
      # Header + 1 data row
      expect(lines.length).to eq(2)
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(PaymentHistory).to receive(:all).and_raise(ActiveRecord::StatementInvalid.new('Database error'))

      expect { described_class.get_histories }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'handles JSON parsing errors' do
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError.new('Invalid JSON'))

      payment_history = create(:payment_history, payment: payment, gateway_response: 'invalid json')
      audit_data = described_class.get_audit_trail_details(payment_history)

      expect(audit_data[:success]).to be true
    end
  end
end
