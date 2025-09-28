require 'rails_helper'

RSpec.describe 'Api::V1::Health', type: :request do
  describe 'GET /api/v1/health' do
    it 'returns health status without authentication' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response).to include(
        'status' => 'ok',
        'message' => 'Phone Store API is running',
        'version' => '1.0.0',
        'database' => 'connected'
      )
      expect(json_response).to have_key('timestamp')

      expect(json_response['timestamp']).to be_present
      expect(Time.parse(json_response['timestamp'])).to be_within(1.second).of(Time.current)
    end

    it 'returns database status as connected when database is active' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response['database']).to eq('connected')
    end

    it 'includes proper JSON structure' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body

      expect(json_response).to be_a(Hash)
      expect(json_response.keys).to contain_exactly('status', 'message', 'version', 'timestamp', 'database')
    end

    it 'does not require authentication' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      # Should not return 401 Unauthorized
    end
  end
end
