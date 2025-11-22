# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::HealthController, type: :controller do
  describe 'GET #index' do
    it 'returns health status' do
      get :index

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['status']).to eq('ok')
      expect(json_response['message']).to eq('Phone Store API is running')
      expect(json_response['version']).to eq('v1')
      expect(json_response['timestamp']).to be_present
      expect(json_response['environment']).to be_present
      expect(json_response['database']).to eq('connected')
    end

    it 'does not require authentication' do
      # No authentication headers
      get :index

      expect(response).to have_http_status(:ok)
    end
  end
end
