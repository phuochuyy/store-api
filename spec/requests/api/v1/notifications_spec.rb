# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Notifications', type: :request do
  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:other_user) { create(:user, role: 'customer') }
  let(:notification) { create(:notification, user: customer_user) }
  let(:admin_notification) { create(:notification, user: admin_user) }

  let(:valid_headers) do
    {
      'Authorization' => "Bearer #{JwtEncodeService.encode(customer_user)}",
      'Content-Type' => 'application/json'
    }
  end

  let(:admin_headers) do
    {
      'Authorization' => "Bearer #{JwtEncodeService.encode(admin_user)}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /api/v1/notifications' do
    let!(:notifications) { create_list(:notification, 3, user: customer_user) }
    let!(:other_notifications) { create_list(:notification, 2, user: other_user) }

    it 'returns user notifications with pagination' do
      get '/api/v1/notifications', headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notifications'].count).to eq(3)
      expect(json_response['data']['pagination']['total_count']).to eq(3)
      expect(json_response['data']['unread_count']).to eq(3)
    end

    it 'filters notifications by type' do
      create(:notification, :stock_alert, user: customer_user)
      create(:notification, :system_alert, user: customer_user)

      get '/api/v1/notifications', params: { notification_type: 'stock_alert' }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['notifications'].count).to eq(1)
      expect(json_response['data']['notifications'].first['notification_type']).to eq('stock_alert')
    end

    it 'filters notifications by read status' do
      notifications.first.update!(read: true)

      get '/api/v1/notifications', params: { read: true }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['notifications'].count).to eq(1)
      expect(json_response['data']['notifications'].first['read']).to be true
    end

    it 'filters notifications by date range' do
      old_notification = create(:notification, user: customer_user, created_at: 1.month.ago)

      get '/api/v1/notifications', params: {
        start_date: 1.week.ago.to_date.to_s,
        end_date: Date.current.to_s
      }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['notifications'].count).to eq(3)
    end

    it 'requires authentication' do
      get '/api/v1/notifications'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/notifications/:id' do
    it 'returns the notification' do
      get "/api/v1/notifications/#{notification.id}", headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notification']['id']).to eq(notification.id)
    end

    it 'returns 404 for non-existent notification' do
      get '/api/v1/notifications/99999', headers: valid_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for other user notification' do
      get "/api/v1/notifications/#{admin_notification.id}", headers: valid_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/notifications/:id' do
    it 'updates the notification' do
      patch "/api/v1/notifications/#{notification.id}",
            params: { notification: { title: 'Updated Title' } }.to_json,
            headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notification']['title']).to eq('Updated Title')
    end

    it 'returns error for invalid update' do
      patch "/api/v1/notifications/#{notification.id}",
            params: { notification: { title: '' } }.to_json,
            headers: valid_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/notifications/:id' do
    it 'deletes the notification' do
      delete "/api/v1/notifications/#{notification.id}", headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(Notification.find_by(id: notification.id)).to be_nil
    end
  end

  describe 'POST /api/v1/notifications/:id/mark_read' do
    it 'marks notification as read' do
      expect(notification.read).to be false

      post "/api/v1/notifications/#{notification.id}/mark_read", headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notification']['read']).to be true
      expect(json_response['data']['notification']['read_at']).to be_present
    end
  end

  describe 'POST /api/v1/notifications/:id/mark_unread' do
    it 'marks notification as unread' do
      notification.update!(read: true, read_at: Time.current)

      post "/api/v1/notifications/#{notification.id}/mark_unread", headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notification']['read']).to be false
      expect(json_response['data']['notification']['read_at']).to be_nil
    end
  end

  describe 'POST /api/v1/notifications/mark_all_read' do
    it 'marks all user notifications as read' do
      create_list(:notification, 3, user: customer_user, read: false)

      post '/api/v1/notifications/mark_all_read', headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['count']).to eq(3)
      expect(customer_user.notifications.unread.count).to eq(0)
    end
  end

  describe 'GET /api/v1/notifications/unread_count' do
    it 'returns unread count' do
      create_list(:notification, 2, user: customer_user, read: false)
      create(:notification, user: customer_user, read: true)

      get '/api/v1/notifications/unread_count', headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['unread_count']).to eq(2)
    end
  end

  describe 'GET /api/v1/notifications/recent' do
    it 'returns recent notifications' do
      create_list(:notification, 5, user: customer_user)

      get '/api/v1/notifications/recent', params: { limit: 3 }, headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['notifications'].count).to eq(3)
      expect(json_response['data']['count']).to eq(3)
    end
  end

  describe 'GET /api/v1/notifications/statistics' do
    it 'returns notification statistics' do
      create_list(:notification, 3, user: customer_user)

      get '/api/v1/notifications/statistics', headers: valid_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['statistics']).to be_present
    end
  end

  # Admin-only endpoints
  describe 'POST /api/v1/notifications/send_stock_alerts' do
    let(:stock_alert) { create(:stock_alert, notification_sent: false) }

    it 'sends stock alert notifications (admin only)' do
      post '/api/v1/notifications/send_stock_alerts',
           params: { alert_ids: [stock_alert.id] }.to_json,
           headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'requires admin role' do
      post '/api/v1/notifications/send_stock_alerts',
           params: { alert_ids: [stock_alert.id] }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns error for missing alert IDs' do
      post '/api/v1/notifications/send_stock_alerts',
           params: {}.to_json,
           headers: admin_headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /api/v1/notifications/send_daily_summary' do
    it 'sends daily summary (admin only)' do
      post '/api/v1/notifications/send_daily_summary', headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'requires admin role' do
      post '/api/v1/notifications/send_daily_summary', headers: valid_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/notifications/send_pending' do
    it 'sends pending notifications (admin only)' do
      post '/api/v1/notifications/send_pending', headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
    end

    it 'requires admin role' do
      post '/api/v1/notifications/send_pending', headers: valid_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
