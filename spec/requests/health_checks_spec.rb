require 'rails_helper'

# /health/all (OkComputer) is the readiness check docker-compose.prod.yml uses, so it has to pass
# when the database and Redis are up.
RSpec.describe 'Health checks', type: :request do
  it 'passes every check when the database and Redis are reachable' do
    get '/health/all'

    expect(response).to have_http_status(:ok), -> { response.body }
    expect(response.body).to include('database: PASSED', 'redis: PASSED', 'sidekiq: PASSED')
  end
end
