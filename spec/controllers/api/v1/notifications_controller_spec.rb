# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Api::V1::NotificationsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:notification) { create(:notification, user: user, read: false) }

  # Helper method to generate JWT token
  def generate_token(user)
    secret_key = Rails.application.credentials.secret_key_base || 'fallback_secret_key'
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }
    JWT.encode(payload, secret_key, 'HS256')
  end

  let(:user_token) { generate_token(user) }
  let(:admin_token) { generate_token(admin_user) }

  before do
    request.headers['Content-Type'] = 'application/json'
    request.headers['Authorization'] = "Bearer #{user_token}"
  end

  describe 'GET #index' do
    before do
      notification
      create(:notification, user: user, read: true)
      create(:notification, user: user, notification_type: 'order_shipped', read: false)
    end

    it 'returns user notifications' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['notifications']).to be_an(Array)
      expect(json_response['data']['pagination']).to be_present
      expect(json_response['data']['unread_count']).to be_present
    end

    it 'filters by notification_type' do
      get :index, params: { notification_type: 'order_shipped' }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['notifications'].all? { |n| n['notification_type'] == 'order_shipped' }).to be true
    end

    it 'filters by read status' do
      get :index, params: { read: true }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['notifications'].all? { |n| n['read'] == true }).to be true
    end

    it 'filters by date range' do
      start_date = 2.days.ago.to_date.to_s
      end_date = Time.zone.today.to_s

      get :index, params: { start_date: start_date, end_date: end_date }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['notifications']).to be_an(Array)
    end

    it 'supports pagination' do
      get :index, params: { page: 1, per_page: 5 }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['pagination']['current_page']).to eq(1)
      expect(json_response['data']['pagination']['per_page']).to eq(5)
    end
  end

  describe 'GET #show' do
    it 'returns notification details' do
      get :show, params: { id: notification.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['notification']).to be_present
      expect(json_response['data']['notification']['id']).to eq(notification.id)
    end

    context 'with non-existent notification' do
      it 'returns not found' do
        get :show, params: { id: 999_999 }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Notification not found')
      end
    end

    context 'with notification from another user' do
      let(:other_user) { create(:user) }
      let(:other_notification) { create(:notification, user: other_user) }

      it 'returns not found' do
        get :show, params: { id: other_notification.id }

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates notification successfully' do
      patch :update, params: {
        id: notification.id,
        notification: {
          title: 'Updated Title',
          message: 'Updated message'
        }
      }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(notification.reload.title).to eq('Updated Title')
    end

    it 'does not allow updating read status directly' do
      patch :update, params: {
        id: notification.id,
        notification: {
          read: true
        }
      }

      # read status should not be updated via update action
      expect(notification.reload.read).to be false
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes notification successfully' do
      delete :destroy, params: { id: notification.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(Notification.find_by(id: notification.id)).to be_nil
    end
  end

  describe 'POST #mark_read' do
    it 'marks notification as read' do
      expect(notification.read).to be false

      post :mark_read, params: { id: notification.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Notification marked as read')
      expect(notification.reload.read).to be true
      expect(notification.read_at).to be_present
    end
  end

  describe 'POST #mark_unread' do
    before do
      notification.update!(read: true, read_at: Time.current)
    end

    it 'marks notification as unread' do
      post :mark_unread, params: { id: notification.id }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Notification marked as unread')
      expect(notification.reload.read).to be false
    end
  end

  describe 'POST #mark_all_read' do
    before do
      create(:notification, user: user, read: false)
      create(:notification, user: user, read: false)
    end

    it 'marks all notifications as read' do
      post :mark_all_read

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['count']).to be >= 2
      expect(user.notifications.unread.count).to eq(0)
    end
  end

  describe 'GET #unread_count' do
    before do
      create(:notification, user: user, read: false)
      create(:notification, user: user, read: false)
    end

    it 'returns unread count' do
      get :unread_count

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['unread_count']).to be >= 2
    end
  end

  describe 'GET #recent' do
    before do
      create_list(:notification, 15, user: user)
    end

    it 'returns recent notifications' do
      get :recent, params: { limit: 10 }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
      expect(json_response['data']['notifications'].length).to be <= 10
    end

    it 'uses default limit if not provided' do
      get :recent

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['data']['notifications'].length).to be <= 10
    end
  end

  describe 'GET #statistics' do
    it 'returns notification statistics' do
      allow(StockAlerts::StockNotificationService).to receive(:get_notification_statistics)
        .and_return({
                      success: true,
                      total_notifications: 100,
                      unread_count: 20,
                      by_type: { 'order_shipped' => 50 }
                    })

      get :statistics, params: { period: 'week' }

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['success']).to be true
    end
  end

  describe 'POST #send_stock_alerts' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockNotificationService).to receive(:send_bulk_stock_alert_notifications)
          .and_return({
                        success: true,
                        message: 'Stock alerts sent successfully',
                        sent_count: 5
                      })
      end

      it 'sends stock alerts successfully' do
        stock_alert = create(:stock_alert)
        post :send_stock_alerts, params: { alert_ids: [stock_alert.id] }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end

      it 'returns error when alert_ids is missing' do
        post :send_stock_alerts

        expect(response).to have_http_status(:bad_request)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Alert IDs are required')
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :send_stock_alerts, params: { alert_ids: [1] }

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #send_daily_summary' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockNotificationService).to receive(:send_daily_stock_alert_summary)
          .and_return({
                        success: true,
                        message: 'Daily summary sent successfully'
                      })
      end

      it 'sends daily summary successfully' do
        post :send_daily_summary

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :send_daily_summary

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end

  describe 'POST #send_pending' do
    context 'as admin' do
      before do
        request.headers['Authorization'] = "Bearer #{admin_token}"
        allow(StockAlerts::StockNotificationService).to receive(:send_pending_notifications)
          .and_return({
                        success: true,
                        message: 'Pending notifications sent successfully'
                      })
      end

      it 'sends pending notifications successfully' do
        post :send_pending

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['success']).to be true
      end
    end

    context 'as regular user' do
      it 'returns forbidden' do
        post :send_pending

        expect(response).to have_http_status(:forbidden)
        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Admin access required')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
