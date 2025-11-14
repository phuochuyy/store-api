require 'rails_helper'

RSpec.describe StockAlert, type: :model do
  let(:product) { create(:product, stock_quantity: 5) }
  let(:alert) { create(:stock_alert, product: product) }

  describe 'associations' do
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it { should validate_presence_of(:alert_type) }
    it { should validate_presence_of(:threshold) }
    it { should validate_presence_of(:current_stock) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:triggered_at) }
    it { should validate_numericality_of(:threshold).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:current_stock).is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it 'defines alert_type enum' do
      expect(StockAlert.alert_types.keys).to include('low_stock', 'out_of_stock', 'critical_stock', 'reorder_point')
    end

    it 'defines status enum' do
      expect(StockAlert.statuses.keys).to include('active', 'resolved', 'dismissed', 'expired')
    end
  end

  describe 'scopes' do
    let!(:active_alert) { create(:stock_alert, status: 'active') }
    let!(:resolved_alert) { create(:stock_alert, :resolved) }

    describe '.active_alerts' do
      it 'returns only active alerts' do
        expect(StockAlert.active_alerts).to include(active_alert)
        expect(StockAlert.active_alerts).not_to include(resolved_alert)
      end
    end

    describe '.by_alert_type' do
      it 'filters by alert type' do
        low_stock_alert = create(:stock_alert, alert_type: 'low_stock')
        expect(StockAlert.by_alert_type('low_stock')).to include(low_stock_alert)
      end
    end
  end

  describe '#severity_level' do
    it 'returns correct severity for each alert type' do
      expect(create(:stock_alert, :out_of_stock).severity_level).to eq('critical')
      expect(create(:stock_alert, :critical).severity_level).to eq('high')
      expect(create(:stock_alert, alert_type: 'low_stock').severity_level).to eq('medium')
      expect(create(:stock_alert, alert_type: 'reorder_point').severity_level).to eq('low')
    end
  end

  describe '#resolve!' do
    it 'marks alert as resolved' do
      alert.resolve!(resolved_by: 'admin', resolution_notes: 'Stock replenished')
      expect(alert.reload.status).to eq('resolved')
      expect(alert.resolved_at).to be_present
    end
  end

  describe '#dismiss!' do
    it 'marks alert as dismissed' do
      alert.dismiss!(dismissed_by: 'admin', dismissal_reason: 'False alarm')
      expect(alert.reload.status).to eq('dismissed')
    end
  end

  describe '.create_alert_for_product' do
    it 'creates alert for product' do
      alert = StockAlert.create_alert_for_product(product, 'low_stock', 10)
      expect(alert).to be_persisted
      expect(alert.product).to eq(product)
      expect(alert.alert_type).to eq('low_stock')
    end

    it 'returns existing alert if one exists' do
      existing = create(:stock_alert, product: product, alert_type: 'low_stock', status: 'active')
      alert = StockAlert.create_alert_for_product(product, 'low_stock', 10)
      expect(alert).to eq(existing)
    end
  end
end

