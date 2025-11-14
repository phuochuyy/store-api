require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:user) { create(:user) }
  let(:notification) { create(:notification, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:notification_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:message) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_length_of(:message).is_at_most(1000) }
    it { should validate_inclusion_of(:read).in_array([true, false]) }
  end

  describe 'scopes' do
    let!(:unread_notification) { create(:notification, user: user, read: false) }
    let!(:read_notification) { create(:notification, :read, user: user) }

    describe '.unread' do
      it 'returns only unread notifications' do
        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe '.by_type' do
      it 'filters by notification type' do
        stock_alert = create(:notification, :stock_alert, user: user)
        expect(Notification.by_type('stock_alert')).to include(stock_alert)
      end
    end
  end

  describe '#mark_as_read!' do
    it 'marks notification as read' do
      notification.mark_as_read!
      expect(notification.reload.read).to be true
      expect(notification.read_at).to be_present
    end
  end

  describe '#mark_as_unread!' do
    it 'marks notification as unread' do
      notification.update!(read: true, read_at: Time.current)
      notification.mark_as_unread!
      expect(notification.reload.read).to be false
      expect(notification.read_at).to be_nil
    end
  end

  describe '#sent?' do
    it 'returns true when sent_at is present' do
      notification.update!(sent_at: Time.current)
      expect(notification.sent?).to be true
    end
  end
end

