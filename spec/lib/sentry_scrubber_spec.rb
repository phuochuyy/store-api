require 'rails_helper'
require 'sentry/test_helper'

# What actually leaves the app: events go through the real SDK pipeline, configured by
# config/initializers/sentry.rb, into a dummy transport.
RSpec.describe 'Sentry scrubbing' do
  include Sentry::TestHelper

  # Request bodies and query strings are not collected by default (data_collection follows
  # send_default_pii = false). Collect them, as one would to debug, to check what gets through.
  before { setup_sentry_test { |config| config.data_collection = Sentry::DataCollection.new } }
  after { teardown_sentry_test }

  let(:body) do
    {
      email: 'jane@example.com',
      user: { name: 'Jane', password: 'hunter22', password_confirmation: 'hunter22' },
      payment: { card: { holder: 'Jane Doe', cvv: '123' } },
      items: [{ product_id: 1, quantity: 2 }]
    }
  end

  def capture_request_error
    env = Rack::MockRequest.env_for('/api/v1/auth/register?page=2&email=jane%40example.com',
                                    method: 'POST', input: body.to_json, 'CONTENT_TYPE' => 'application/json')
    Sentry.with_scope do |scope|
      scope.set_rack_env(env)
      Sentry.capture_exception(RuntimeError.new('boom'))
    end
    sentry_events.last
  end

  it 'masks secrets in the request body at any depth and keeps everything else' do
    data = capture_request_error.request.data

    expect(data.dig('user', 'password')).to eq('[FILTERED]')
    expect(data.dig('user', 'password_confirmation')).to eq('[FILTERED]')
    expect(data['email']).to eq('[FILTERED]')
    expect(data.dig('payment', 'card', 'cvv')).to eq('[FILTERED]')
    expect(data.dig('user', 'name')).to eq('Jane')
    expect(data.dig('payment', 'card', 'holder')).to eq('Jane Doe')
    expect(data['items']).to eq([{ 'product_id' => 1, 'quantity' => 2 }])
  end

  it 'masks secrets in the query string' do
    query = capture_request_error.request.query_string

    expect(query.to_s).not_to include('jane')
    expect(query.to_s).to include('2')
  end

  it 'masks secrets the app attaches as extra data' do
    Sentry.set_extras(params: { user: { password: 'hunter22' } }, attempt: 3)
    Sentry.capture_message('with extras')

    extra = sentry_events.last.extra
    expect(extra.dig(:params, :user, :password)).to eq('[FILTERED]')
    expect(extra[:attempt]).to eq(3)
  end

  it 'masks secrets in breadcrumbs' do
    breadcrumb = Sentry::Breadcrumb.new(category: 'auth', data: { user: { password: 'hunter22' }, attempt: 1 })
    Sentry.add_breadcrumb(breadcrumb)
    Sentry.capture_message('after a breadcrumb')

    crumb = sentry_events.last.breadcrumbs.peek
    expect(crumb.data.dig(:user, :password)).to eq('[FILTERED]')
    expect(crumb.data[:attempt]).to eq(1)
  end
end
