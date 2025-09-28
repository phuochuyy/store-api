# frozen_string_literal: true

class NotificationSerializer
  def self.serialize(notification)
    {
      id: notification.id,
      notification_type: notification.notification_type,
      title: notification.title,
      message: notification.message,
      read: notification.read,
      read_at: notification.read_at,
      sent_at: notification.sent_at,
      metadata: notification.metadata,
      created_at: notification.created_at,
      updated_at: notification.updated_at,
      user: {
        id: notification.user.id,
        name: notification.user.name,
        email: notification.user.email
      }
    }
  end

  def self.serialize_collection(notifications)
    notifications.map { |notification| serialize(notification) }
  end

  def self.serialize_with_summary(notifications, unread_count = 0)
    {
      notifications: serialize_collection(notifications),
      unread_count: unread_count,
      total_count: notifications.count
    }
  end
end
