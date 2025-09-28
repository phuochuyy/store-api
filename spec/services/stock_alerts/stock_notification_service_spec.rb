# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StockAlerts::StockNotificationService, type: :service do
  let(:admin_user1) { create(:user, role: 'admin') }
  let(:admin_user2) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:product) { create(:product) }
  let(:stock_alert) { create(:stock_alert, product: product, notification_sent: false) }

  before do
    # Ensure we have admin users
    admin_user1
    admin_user2
  end

  describe '.send_stock_alert_notification' do
    context 'when stock alert is valid' do
      it 'sends notifications to all admin users' do
        result = described_class.send_stock_alert_notification(stock_alert)

        expect(result[:success]).to be true
        expect(result[:notifications_created]).to eq(2)
        expect(result[:total_admins]).to eq(2)
        expect(result[:errors]).to be_empty

        # Check that notifications were created
        expect(Notification.where(user: [admin_user1, admin_user2]).count).to eq(2)
        expect(Notification.stock_alert.count).to eq(2)
      end

      it 'marks stock alert as notification sent' do
        expect(stock_alert.notification_sent).to be false

        described_class.send_stock_alert_notification(stock_alert)

        stock_alert.reload
        expect(stock_alert.notification_sent).to be true
      end

      it 'creates notifications with correct attributes' do
        described_class.send_stock_alert_notification(stock_alert)

        notification = Notification.stock_alert.first
        expect(notification.title).to eq("Stock Alert: #{product.name}")
        expect(notification.message).to eq(stock_alert.message)
        expect(notification.metadata['stock_alert_id']).to eq(stock_alert.id)
        expect(notification.metadata['product_id']).to eq(product.id)
        expect(notification.metadata['alert_type']).to eq(stock_alert.alert_type)
      end
    end

    context 'when stock alert is invalid' do
      it 'returns error for nil stock alert' do
        result = described_class.send_stock_alert_notification(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Stock alert not found')
      end

      it 'returns error when notification already sent' do
        stock_alert.update!(notification_sent: true)

        result = described_class.send_stock_alert_notification(stock_alert)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Stock alert already has notification sent')
      end
    end

    context 'when no admin users exist' do
      before do
        User.admin.destroy_all
      end

      it 'returns error' do
        result = described_class.send_stock_alert_notification(stock_alert)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('No admin users found')
      end
    end

    context 'when notification creation fails' do
      before do
        allow(Notification).to receive(:create_stock_alert_notification).and_raise(StandardError, 'Database error')
      end

      it 'handles errors gracefully' do
        result = described_class.send_stock_alert_notification(stock_alert)

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include('Database error')
      end
    end
  end

  describe '.send_bulk_stock_alert_notifications' do
    let(:stock_alert2) { create(:stock_alert, product: product, notification_sent: false) }
    let(:stock_alerts) { [stock_alert, stock_alert2] }

    it 'sends notifications for multiple stock alerts' do
      result = described_class.send_bulk_stock_alert_notifications(stock_alerts)

      expect(result[:success]).to be true
      expect(result[:results][:total_alerts]).to eq(2)
      expect(result[:results][:notifications_sent]).to eq(4) # 2 alerts × 2 admins
      expect(result[:results][:alerts_processed]).to eq(2)
    end

    it 'handles mixed success and failure' do
      stock_alert2.update!(notification_sent: true) # This will fail

      result = described_class.send_bulk_stock_alert_notifications(stock_alerts)

      expect(result[:success]).to be true # At least one succeeded
      expect(result[:results][:notifications_sent]).to eq(2) # Only first alert
      expect(result[:results][:errors]).not_to be_empty
    end

    it 'returns error for empty array' do
      result = described_class.send_bulk_stock_alert_notifications([])

      expect(result[:success]).to be false
      expect(result[:error]).to eq('No stock alerts provided')
    end
  end

  describe '.send_critical_stock_alert_notifications' do
    let(:critical_alert) do
      create(:stock_alert, product: product, alert_type: 'out_of_stock', notification_sent: false)
    end
    let(:low_stock_alert) { create(:stock_alert, product: product, alert_type: 'low_stock', notification_sent: false) }

    before do
      critical_alert
      low_stock_alert
    end

    it 'sends notifications only for critical alerts' do
      result = described_class.send_critical_stock_alert_notifications

      expect(result[:success]).to be true
      expect(result[:results][:total_alerts]).to eq(1) # Only critical alert
      expect(result[:results][:notifications_sent]).to eq(2) # 1 alert × 2 admins
    end

    it 'returns success message when no critical alerts pending' do
      critical_alert.update!(notification_sent: true)

      result = described_class.send_critical_stock_alert_notifications

      expect(result[:success]).to be true
      expect(result[:message]).to eq('No critical alerts pending notification')
    end
  end

  describe '.send_daily_stock_alert_summary' do
    it 'sends daily summary to all admin users' do
      result = described_class.send_daily_stock_alert_summary

      expect(result[:success]).to be true
      expect(result[:notifications_created]).to eq(2)
      expect(result[:total_admins]).to eq(2)

      # Check that system notifications were created
      expect(Notification.system_alert.count).to eq(2)
    end

    it 'creates notifications with correct attributes' do
      described_class.send_daily_stock_alert_summary

      notification = Notification.system_alert.first
      expect(notification.title).to include('Daily Stock Alert Summary')
      expect(notification.message).to include('Daily Stock Alert Summary:')
      expect(notification.metadata['summary_type']).to eq('daily_stock_summary')
    end

    it 'returns error when no admin users exist' do
      User.admin.destroy_all

      result = described_class.send_daily_stock_alert_summary

      expect(result[:success]).to be false
      expect(result[:error]).to eq('No admin users found')
    end
  end

  describe '.send_pending_notifications' do
    let(:pending_alert) { create(:stock_alert, product: product, notification_sent: false) }
    let(:sent_alert) { create(:stock_alert, product: product, notification_sent: true) }

    before do
      pending_alert
      sent_alert
    end

    it 'sends notifications only for pending alerts' do
      result = described_class.send_pending_notifications

      expect(result[:success]).to be true
      expect(result[:results][:total_alerts]).to eq(1) # Only pending alert
      expect(result[:results][:notifications_sent]).to eq(2) # 1 alert × 2 admins
    end

    it 'returns success message when no pending alerts' do
      pending_alert.update!(notification_sent: true)

      result = described_class.send_pending_notifications

      expect(result[:success]).to be true
      expect(result[:message]).to eq('No alerts pending notification')
    end
  end

  describe '.get_notification_statistics' do
    let!(:stock_notification) { create(:notification, :stock_alert, user: admin_user1, created_at: 2.days.ago) }
    let!(:system_notification) { create(:notification, :system_alert, user: admin_user1, created_at: 1.day.ago) }
    let!(:old_notification) { create(:notification, user: admin_user1, created_at: 2.weeks.ago) }

    it 'returns statistics for the specified period' do
      result = described_class.get_notification_statistics('week')

      expect(result[:success]).to be true
      expect(result[:period]).to eq('week')
      expect(result[:statistics][:total_notifications]).to eq(2) # Only recent ones
      expect(result[:statistics][:stock_alert_notifications]).to eq(1)
      expect(result[:statistics][:system_notifications]).to eq(1)
    end

    it 'calculates average notifications per day' do
      result = described_class.get_notification_statistics('week')

      expect(result[:statistics][:average_notifications_per_day]).to be >= 0
    end

    it 'groups notifications by type and user role' do
      result = described_class.get_notification_statistics('week')

      expect(result[:statistics][:notifications_by_type]).to include('stock_alert' => 1, 'system_alert' => 1)
      expect(result[:statistics][:notifications_by_user]).to include('admin' => 2)
    end
  end
end
