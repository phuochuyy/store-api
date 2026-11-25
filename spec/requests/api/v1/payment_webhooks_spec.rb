require 'rails_helper'

# Gateways report payment outcomes to POST /api/v1/payments/webhooks/:gateway. Events are signed
# with a per-gateway secret (HMAC-SHA256 of the raw body) and applied at most once.
RSpec.describe 'Payment webhooks', type: :request do
  let(:secret) { 'whsec_test' }
  let(:order) { create(:order, :with_items, total_amount: 200.00) }
  let(:stripe) { create(:payment_method, gateway_type: 'stripe') }
  let(:payment) do
    create(:payment, order: order, payment_method: stripe, status: 'pending', amount: 200.00, transaction_id: 'pi_123')
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil).and_return(secret)
    allow(ENV).to receive(:fetch).with('PAYPAL_WEBHOOK_SECRET', nil).and_return(secret)
  end

  def stripe_event(type, id: 'evt_1', transaction_id: payment.transaction_id)
    { id: id, type: type, data: { object: { id: transaction_id } } }
  end

  def deliver(gateway, event, signing_secret: secret)
    body = event.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', signing_secret, body)
    headers = { 'Content-Type' => 'application/json', 'X-Webhook-Signature' => "sha256=#{signature}" }
    post "/api/v1/payments/webhooks/#{gateway}", params: body, headers: headers
  end

  it 'a succeeded event completes a pending payment and marks the order paid' do
    deliver('stripe', stripe_event('payment_intent.succeeded'))

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('completed')
    expect(order.reload.payment_status).to eq('paid')
  end

  it 'a failed event marks a pending payment failed' do
    deliver('stripe', stripe_event('payment_intent.payment_failed'))

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('failed')
    expect(order.reload.payment_status).to eq('payment_failed')
  end

  it 'understands PayPal events' do
    paypal_payment = create(:payment, order: order, payment_method: create(:payment_method, :paypal),
                                      status: 'pending', amount: 200.00, transaction_id: 'PAY-9')
    deliver('paypal', { id: 'WH-1', event_type: 'PAYMENT.SALE.COMPLETED', resource: { id: 'PAY-9' } })

    expect(response).to have_http_status(:ok)
    expect(paypal_payment.reload.status).to eq('completed')
  end

  it 'refuses an event signed with the wrong secret' do
    deliver('stripe', stripe_event('payment_intent.succeeded'), signing_secret: 'not-the-secret')

    expect(response).to have_http_status(:unauthorized)
    expect(payment.reload.status).to eq('pending')
  end

  it 'refuses every event while no secret is configured' do
    allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil).and_return(nil)
    deliver('stripe', stripe_event('payment_intent.succeeded'))

    expect(response).to have_http_status(:service_unavailable)
    expect(payment.reload.status).to eq('pending')
  end

  it 'applies an event delivered twice only once' do
    deliver('stripe', stripe_event('payment_intent.succeeded'))
    payment.reload.update!(status: 'refunded')
    deliver('stripe', stripe_event('payment_intent.succeeded'))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'duplicate')).to be true
    expect(payment.reload.status).to eq('refunded')
  end

  it 'never turns a completed payment back into a failed one' do
    payment.update!(status: 'completed')
    deliver('stripe', stripe_event('payment_intent.payment_failed'))

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('completed')
  end

  it 'records a dispute on the payment without changing its status' do
    payment.update!(status: 'completed')
    deliver('stripe', stripe_event('charge.dispute.created'))

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('completed')
    expect(payment.metadata['dispute']).to include('event_id' => 'evt_1')
  end

  it 'answers 404 for a payment it does not know' do
    deliver('stripe', stripe_event('payment_intent.succeeded', transaction_id: 'pi_unknown'))

    expect(response).to have_http_status(:not_found)
  end
end
