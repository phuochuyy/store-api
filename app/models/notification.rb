# frozen_string_literal: true

# == Schema Information
#
# Table name: notifications
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  notification_type :string           not null
#  title             :string           not null
#  message           :text             not null
#  read              :boolean          default(FALSE), not null
#  metadata          :json
#  read_at           :datetime
#  sent_at           :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_notifications_on_notification_type  (notification_type)
#  index_notifications_on_read               (read)
#  index_notifications_on_user_id_and_notification_type  (user_id,notification_type)
#  index_notifications_on_user_id_and_read   (user_id,read)
#

class Notification < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :notification_type, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 1000 }
  validates :read, inclusion: { in: [true, false] }

  enum :notification_type, {
    stock_alert: 'stock_alert',
    order_update: 'order_update',
    order_confirmed: 'order_confirmed',
    order_cancelled: 'order_cancelled',
    order_shipped: 'order_shipped',
    order_delivered: 'order_delivered',
    order_confirmed_admin: 'order_confirmed_admin',
    order_cancelled_admin: 'order_cancelled_admin',
    order_shipped_admin: 'order_shipped_admin',
    order_delivered_admin: 'order_delivered_admin',
    payment_update: 'payment_update',
    system_alert: 'system_alert',
    promotion: 'promotion',
    review_approved: 'review_approved',
    review_rejected: 'review_rejected',
    wishlist_reminder: 'wishlist_reminder',
    price_drop: 'price_drop',
    product_available: 'product_available',
    password_reset_success: 'password_reset_success',
    account_deactivated: 'account_deactivated',
    order_reminder: 'order_reminder'
  }

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :pending, -> { where(sent_at: nil) }

  before_validation :set_defaults
  after_create :set_sent_at

  # Methods
  def mark_as_read!
    update!(read: true, read_at: Time.current)
  end

  def mark_as_unread!
    update!(read: false, read_at: nil)
  end

  def read?
    read
  end

  def unread?
    !read
  end

  def sent?
    sent_at.present?
  end

  def pending?
    sent_at.nil?
  end

  def self.create_stock_alert_notification(user, stock_alert)
    create!(
      user: user,
      notification_type: 'stock_alert',
      title: "Stock Alert: #{stock_alert.product.name}",
      message: stock_alert.message,
      metadata: {
        stock_alert_id: stock_alert.id,
        product_id: stock_alert.product_id,
        product_name: stock_alert.product.name,
        alert_type: stock_alert.alert_type,
        severity_level: stock_alert.severity_level,
        current_stock: stock_alert.current_stock,
        threshold: stock_alert.threshold
      }
    )
  end

  def self.create_system_notification(user, title, message, metadata = {})
    create!(
      user: user,
      notification_type: 'system_alert',
      title: title,
      message: message,
      metadata: metadata
    )
  end

  def self.create_promotion_notification(user, title, message, metadata = {})
    create!(
      user: user,
      notification_type: 'promotion',
      title: title,
      message: message,
      metadata: metadata
    )
  end

  def self.mark_all_as_read_for_user(user)
    where(user: user, read: false).find_each do |notification|
      notification.update!(read: true, read_at: Time.current)
    end
  end

  def self.get_unread_count_for_user(user)
    where(user: user, read: false).count
  end

  def self.get_recent_notifications_for_user(user, limit = 10)
    where(user: user).recent.limit(limit)
  end

  private

  def set_defaults
    self.read ||= false
  end

  def set_sent_at
    update!(sent_at: Time.current) if sent_at.nil?
  end
end
