# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StockAlert, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      stock_alert = build(:stock_alert)
      expect(stock_alert).to be_valid
    end

    it 'is invalid without an alert_type' do
      stock_alert = build(:stock_alert, alert_type: nil)
      expect(stock_alert).not_to be_valid
      expect(stock_alert.errors[:alert_type]).to include("can't be blank")
    end

    it 'is invalid without a threshold' do
      stock_alert = build(:stock_alert, threshold: nil)
      expect(stock_alert).not_to be_valid
      expect(stock_alert.errors[:threshold]).to include("can't be blank")
    end

    it 'is invalid with negative threshold' do
      stock_alert = build(:stock_alert, threshold: -1)
      expect(stock_alert).not_to be_valid
      expect(stock_alert.errors[:threshold]).to include('must be greater than or equal to 0')
    end

    it 'is invalid without current_stock' do
      stock_alert = build(:stock_alert, current_stock: nil)
      expect(stock_alert).not_to be_valid
      expect(stock_alert.errors[:current_stock]).to include("can't be blank")
    end

    it 'is invalid with negative current_stock' do
      stock_alert = build(:stock_alert, current_stock: -1)
      expect(stock_alert).not_to be_valid
      expect(stock_alert.errors[:current_stock]).to include('must be greater than or equal to 0')
    end

    it 'sets default status when nil' do
      stock_alert = build(:stock_alert, status: nil)
      stock_alert.valid?
      expect(stock_alert.status).to eq('active')
    end

    it 'sets default triggered_at when nil' do
      stock_alert = build(:stock_alert, triggered_at: nil)
      stock_alert.valid?
      expect(stock_alert.triggered_at).to be_present
    end
  end

  describe 'enums' do
    it 'defines alert_type enum correctly' do
      expect(StockAlert.alert_types).to eq({
                                             'low_stock' => 'low_stock',
                                             'out_of_stock' => 'out_of_stock',
                                             'critical_stock' => 'critical_stock',
                                             'reorder_point' => 'reorder_point'
                                           })
    end

    it 'defines status enum correctly' do
      expect(StockAlert.statuses).to eq({
                                          'active' => 'active',
                                          'resolved' => 'resolved',
                                          'dismissed' => 'dismissed',
                                          'expired' => 'expired'
                                        })
    end
  end

  describe 'scopes' do
    let!(:active_alert) { create(:stock_alert, status: 'active') }
    let!(:resolved_alert) { create(:stock_alert, :resolved) }
    let!(:dismissed_alert) { create(:stock_alert, :dismissed) }
    let!(:low_stock_alert) { create(:stock_alert, :low_stock) }
    let!(:out_of_stock_alert) { create(:stock_alert, :out_of_stock) }

    describe '.recent' do
      it 'orders alerts by triggered_at desc' do
        expect(StockAlert.recent.first).to eq(out_of_stock_alert)
      end
    end

    describe '.active_alerts' do
      it 'returns only active alerts' do
        expect(StockAlert.active_alerts).to include(active_alert)
        expect(StockAlert.active_alerts).not_to include(resolved_alert, dismissed_alert)
      end
    end

    describe '.resolved_alerts' do
      it 'returns only resolved alerts' do
        expect(StockAlert.resolved_alerts).to include(resolved_alert)
        expect(StockAlert.resolved_alerts).not_to include(active_alert, dismissed_alert)
      end
    end

    describe '.unresolved' do
      it 'returns only active alerts' do
        expect(StockAlert.unresolved).to include(active_alert)
        expect(StockAlert.unresolved).not_to include(resolved_alert, dismissed_alert)
      end
    end

    describe '.by_alert_type' do
      it 'filters alerts by alert type' do
        expect(StockAlert.by_alert_type('low_stock')).to include(low_stock_alert)
        expect(StockAlert.by_alert_type('low_stock')).not_to include(out_of_stock_alert)
      end
    end

    describe '.notification_pending' do
      it 'returns alerts with notification_sent false' do
        pending_alert = create(:stock_alert, notification_sent: false)
        sent_alert = create(:stock_alert, :notification_sent)

        expect(StockAlert.notification_pending).to include(pending_alert)
        expect(StockAlert.notification_pending).not_to include(sent_alert)
      end
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      stock_alert = StockAlert.new(product: create(:product), alert_type: 'low_stock', threshold: 10, current_stock: 5)
      stock_alert.valid?
      expect(stock_alert.triggered_at).to be_present
      expect(stock_alert.status).to eq('active')
      expect(stock_alert.notification_sent).to be false
    end

    it 'generates message before validation' do
      product = create(:product, name: 'Test Product')
      stock_alert = StockAlert.new(product: product, alert_type: 'low_stock', threshold: 10, current_stock: 5)
      stock_alert.valid?
      expect(stock_alert.message).to include('Test Product')
      expect(stock_alert.message).to include('low stock level')
    end
  end

  describe 'methods' do
    let(:stock_alert) { create(:stock_alert, :low_stock) }

    describe '#severity_level' do
      it 'returns correct severity level for low_stock' do
        expect(stock_alert.severity_level).to eq('medium')
      end

      it 'returns correct severity level for out_of_stock' do
        out_of_stock_alert = create(:stock_alert, :out_of_stock)
        expect(out_of_stock_alert.severity_level).to eq('critical')
      end

      it 'returns correct severity level for critical_stock' do
        critical_alert = create(:stock_alert, :critical_stock)
        expect(critical_alert.severity_level).to eq('high')
      end

      it 'returns correct severity level for reorder_point' do
        reorder_alert = create(:stock_alert, :reorder_point)
        expect(reorder_alert.severity_level).to eq('low')
      end
    end

    describe '#severity_score' do
      it 'returns correct severity score' do
        expect(stock_alert.severity_score).to eq(2) # medium
      end
    end

    describe '#duration' do
      it 'returns nil when not resolved' do
        expect(stock_alert.duration).to be_nil
      end

      it 'returns duration when resolved' do
        resolved_alert = create(:stock_alert, :resolved)
        expect(resolved_alert.duration).to be_present
        expect(resolved_alert.duration).to be > 0
      end
    end

    describe '#active_duration' do
      it 'returns active duration for active alerts' do
        expect(stock_alert.active_duration).to be_present
        expect(stock_alert.active_duration).to be > 0
      end

      it 'returns nil for resolved alerts' do
        resolved_alert = create(:stock_alert, :resolved)
        expect(resolved_alert.active_duration).to be_nil
      end
    end

    describe '#resolve!' do
      it 'resolves the alert' do
        stock_alert.resolve!(resolved_by: 'admin', resolution_notes: 'Stock replenished')

        expect(stock_alert.status).to eq('resolved')
        expect(stock_alert.resolved_at).to be_present
        expect(stock_alert.metadata['resolved_by']).to eq('admin')
        expect(stock_alert.metadata['resolution_notes']).to eq('Stock replenished')
      end
    end

    describe '#dismiss!' do
      it 'dismisses the alert' do
        stock_alert.dismiss!(dismissed_by: 'admin', dismissal_reason: 'False alarm')

        expect(stock_alert.status).to eq('dismissed')
        expect(stock_alert.resolved_at).to be_present
        expect(stock_alert.metadata['dismissed_by']).to eq('admin')
        expect(stock_alert.metadata['dismissal_reason']).to eq('False alarm')
      end
    end

    describe '#mark_notification_sent!' do
      it 'marks notification as sent' do
        stock_alert.mark_notification_sent!
        expect(stock_alert.notification_sent).to be true
      end
    end

    describe '#generate_message' do
      it 'generates correct message for low stock' do
        product = create(:product, name: 'Test Product')
        alert = create(:stock_alert, product: product, alert_type: 'low_stock', threshold: 10, current_stock: 5)
        message = alert.generate_message

        expect(message).to include('Test Product')
        expect(message).to include('low stock level')
        expect(message).to include('5 units remaining')
        expect(message).to include('threshold: 10')
      end
    end
  end

  describe 'class methods' do
    let(:product) { create(:product, stock_quantity: 3) }

    describe '.create_alert_for_product' do
      it 'creates alert for product' do
        alert = StockAlert.create_alert_for_product(product, 'critical_stock', 5)

        expect(alert).to be_persisted
        expect(alert.product).to eq(product)
        expect(alert.alert_type).to eq('critical_stock')
        expect(alert.threshold).to eq(5)
        expect(alert.current_stock).to eq(3)
      end

      it 'does not create duplicate active alerts' do
        StockAlert.create_alert_for_product(product, 'critical_stock', 5)
        existing_alert = StockAlert.create_alert_for_product(product, 'critical_stock', 5)

        expect(existing_alert).to be_persisted
        expect(StockAlert.active_alerts.where(product: product, alert_type: 'critical_stock').count).to eq(1)
      end
    end

    describe '.check_and_create_alerts_for_product' do
      it 'creates out of stock alert when stock is 0' do
        product.update!(stock_quantity: 0)
        alerts = StockAlert.check_and_create_alerts_for_product(product)

        expect(alerts.size).to eq(1)
        expect(alerts.first.alert_type).to eq('out_of_stock')
      end

      it 'creates critical stock alert when stock is 1-5' do
        product.update!(stock_quantity: 3)
        alerts = StockAlert.check_and_create_alerts_for_product(product)

        expect(alerts.size).to eq(1)
        expect(alerts.first.alert_type).to eq('critical_stock')
      end

      it 'creates low stock alert when stock is 6-10' do
        product.update!(stock_quantity: 7)
        alerts = StockAlert.check_and_create_alerts_for_product(product)

        expect(alerts.size).to eq(1)
        expect(alerts.first.alert_type).to eq('low_stock')
      end

      it 'creates reorder point alert when stock is 11-20' do
        product.update!(stock_quantity: 15)
        alerts = StockAlert.check_and_create_alerts_for_product(product)

        expect(alerts.size).to eq(1)
        expect(alerts.first.alert_type).to eq('reorder_point')
      end

      it 'does not create alerts when stock is sufficient' do
        product.update!(stock_quantity: 25)
        alerts = StockAlert.check_and_create_alerts_for_product(product)

        expect(alerts.size).to eq(0)
      end
    end

    describe '.resolve_alerts_for_product' do
      it 'resolves alerts when stock improves' do
        # Create an active low stock alert
        alert = create(:stock_alert, product: product, alert_type: 'low_stock', threshold: 10, current_stock: 5)

        # Increase stock above threshold
        product.update!(stock_quantity: 15)
        StockAlert.resolve_alerts_for_product(product)

        expect(alert.reload.status).to eq('resolved')
        expect(alert.resolved_at).to be_present
      end

      it 'does not resolve alerts when stock is still low' do
        # Create an active low stock alert
        alert = create(:stock_alert, product: product, alert_type: 'low_stock', threshold: 10, current_stock: 5)

        # Stock is still below threshold
        product.update!(stock_quantity: 8)
        StockAlert.resolve_alerts_for_product(product)

        expect(alert.reload.status).to eq('active')
      end
    end
  end

  describe 'associations' do
    it 'belongs to a product' do
      product = create(:product)
      stock_alert = create(:stock_alert, product: product)
      expect(stock_alert.product).to eq(product)
    end
  end
end
