# frozen_string_literal: true

# == Schema Information
#
# Table name: stock_alerts
#
#  id               :integer          not null, primary key
#  product_id       :integer          not null
#  alert_type       :string           not null
#  threshold        :integer          not null
#  current_stock    :integer          not null
#  status           :string           default("active"), not null
#  triggered_at     :datetime         not null
#  resolved_at      :datetime
#  notification_sent :boolean          default(FALSE), not null
#  message          :text
#  metadata         :json
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class StockAlert < ApplicationRecord
  # Associations
  belongs_to :product

  # Validations
  validates :alert_type, presence: true
  validates :threshold, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :current_stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :triggered_at, presence: true

  enum :alert_type, {
    low_stock: 'low_stock',
    out_of_stock: 'out_of_stock',
    critical_stock: 'critical_stock',
    reorder_point: 'reorder_point'
  }

  enum :status, {
    active: 'active',
    resolved: 'resolved',
    dismissed: 'dismissed',
    expired: 'expired'
  }

  scope :recent, -> { order(triggered_at: :desc) }
  scope :active_alerts, -> { where(status: 'active') }
  scope :resolved_alerts, -> { where(status: 'resolved') }
  scope :unresolved, -> { where(status: %w[active]) }
  scope :by_alert_type, ->(type) { where(alert_type: type) }
  scope :by_product, ->(product) { where(product: product) }
  scope :notification_pending, -> { where(notification_sent: false) }
  scope :notification_sent, -> { where(notification_sent: true) }

  before_validation :set_defaults
  after_create :update_product_alert_status
  after_create :send_notification_if_needed

  # Methods
  def severity_level
    case alert_type
    when 'out_of_stock'
      'critical'
    when 'critical_stock'
      'high'
    when 'low_stock'
      'medium'
    when 'reorder_point'
      'low'
    else
      'unknown'
    end
  end

  def severity_score
    case severity_level
    when 'critical'
      4
    when 'high'
      3
    when 'medium'
      2
    when 'low'
      1
    else
      0
    end
  end

  def duration
    return nil unless resolved_at

    resolved_at - triggered_at
  end

  def active_duration
    return nil if resolved?

    Time.current - triggered_at
  end

  def resolve!(resolved_by: nil, resolution_notes: nil)
    update!(
      status: 'resolved',
      resolved_at: Time.current,
      metadata: (metadata || {}).merge(
        'resolved_by' => resolved_by,
        'resolution_notes' => resolution_notes,
        'resolved_at' => Time.current.iso8601
      )
    )
  end

  def dismiss!(dismissed_by: nil, dismissal_reason: nil)
    update!(
      status: 'dismissed',
      resolved_at: Time.current,
      metadata: (metadata || {}).merge(
        'dismissed_by' => dismissed_by,
        'dismissal_reason' => dismissal_reason,
        'dismissed_at' => Time.current.iso8601
      )
    )
  end

  def mark_notification_sent!
    update!(notification_sent: true)
  end

  def generate_message
    case alert_type
    when 'out_of_stock'
      "Product '#{product.name}' is out of stock (0 units remaining)"
    when 'critical_stock'
      "Product '#{product.name}' has critical stock level (#{current_stock} units remaining, threshold: #{threshold})"
    when 'low_stock'
      "Product '#{product.name}' has low stock level (#{current_stock} units remaining, threshold: #{threshold})"
    when 'reorder_point'
      "Product '#{product.name}' has reached reorder point (#{current_stock} units remaining, threshold: #{threshold})"
    else
      "Stock alert for product '#{product.name}'"
    end
  end

  def self.create_alert_for_product(product, alert_type, threshold = nil)
    existing_alert = active_alerts.find_by(product: product, alert_type: alert_type)
    return existing_alert if existing_alert

    threshold ||= default_threshold_for_alert_type(alert_type)

    create!(
      product: product,
      alert_type: alert_type,
      threshold: threshold,
      current_stock: product.stock_quantity,
      triggered_at: Time.current,
      message: generate_alert_message(product, alert_type, threshold, product.stock_quantity)
    )
  end

  def self.default_threshold_for_alert_type(alert_type)
    case alert_type
    when 'out_of_stock'
      0
    when 'critical_stock'
      5
    when 'reorder_point'
      20
    else
      # Default to low_stock threshold (includes 'low_stock' and nil)
      10
    end
  end

  def self.generate_alert_message(product, alert_type, threshold, current_stock)
    case alert_type
    when 'out_of_stock'
      "Product '#{product.name}' is out of stock (0 units remaining)"
    when 'critical_stock'
      "Product '#{product.name}' has critical stock level (#{current_stock} units remaining, threshold: #{threshold})"
    when 'low_stock'
      "Product '#{product.name}' has low stock level (#{current_stock} units remaining, threshold: #{threshold})"
    when 'reorder_point'
      "Product '#{product.name}' has reached reorder point (#{current_stock} units remaining, threshold: #{threshold})"
    else
      "Unknown stock alert for product '#{product.name}'"
    end
  end

  def self.check_and_create_alerts_for_product(product)
    alerts_created = []

    # Check for out of stock
    alerts_created << create_alert_for_product(product, 'out_of_stock', 0) if product.stock_quantity <= 0

    # Check for critical stock (1-5 units)
    if product.stock_quantity.positive? && product.stock_quantity <= 5
      alerts_created << create_alert_for_product(product, 'critical_stock', 5)
    end

    # Check for low stock (6-10 units)
    if product.stock_quantity > 5 && product.stock_quantity <= 10
      alerts_created << create_alert_for_product(product, 'low_stock', 10)
    end

    # Check for reorder point (11-20 units)
    if product.stock_quantity > 10 && product.stock_quantity <= 20
      alerts_created << create_alert_for_product(product, 'reorder_point', 20)
    end

    alerts_created.compact
  end

  def self.resolve_alerts_for_product(product)
    active_alerts.where(product: product).find_each do |alert|
      should_resolve = case alert.alert_type
                       when 'out_of_stock'
                         product.stock_quantity.positive?
                       when 'critical_stock'
                         product.stock_quantity > 5
                       when 'low_stock'
                         product.stock_quantity > 10
                       when 'reorder_point'
                         product.stock_quantity > 20
                       else
                         false
                       end

      alert.resolve! if should_resolve
    end
  end

  def set_defaults
    self.triggered_at ||= Time.current
    self.status ||= 'active'
    self.notification_sent ||= false
    self.message ||= generate_message
  end

  def update_product_alert_status
    # This could be used to update a cached alert status on the product
    # For now, we'll just log the alert creation
    Rails.logger.info "Stock alert created: #{alert_type} for product #{product.name} (ID: #{product.id})"
  end

  def send_notification_if_needed
    # Only send notifications for critical alerts automatically
    return unless %w[out_of_stock critical_stock].include?(alert_type)

    # Send notification in background to avoid blocking
    StockAlertNotificationJob.perform_later(self)
  end

  private_class_method :check_and_create_alerts_for_product, :resolve_alerts_for_product
end
