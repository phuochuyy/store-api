# frozen_string_literal: true

# Rate limiting configuration using Rack::Attack
# See: https://github.com/rack/rack-attack

class Rack::Attack
  # Configure cache store (use Redis in production, memory in development)
  if Rails.env.production?
    self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      namespace: 'rack_attack'
    )
  else
    self.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Enable logging
  ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, payload|
    req = payload.is_a?(Hash) ? payload[:request] : payload
    if req.respond_to?(:env) && req.respond_to?(:path)
      Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type']} #{req.path}"
    end
  end

  # Throttle all requests by IP (60 requests per minute)
  throttle('req/ip', limit: 60, period: 1.minute) do |req|
    req.ip unless req.path.start_with?('/api/v1/health')
  end

  # Throttle login attempts by IP (5 attempts per 20 seconds)
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email (5 attempts per 20 seconds)
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      # Normalize email to prevent bypass attempts
      email = req.params['email'].to_s.downcase.gsub(/\s+/, '')
      email.presence
    end
  end

  # Throttle registration attempts by IP (3 attempts per hour)
  throttle('registrations/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/api/v1/auth/register' && req.post?
      req.ip
    end
  end

  # Throttle password reset attempts by IP (5 attempts per hour)
  throttle('password_resets/ip', limit: 5, period: 1.hour) do |req|
    if req.path.include?('password_reset') && req.post?
      req.ip
    end
  end

  # Throttle API requests by IP (100 requests per minute)
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/')
      req.ip
    end
  end

  # Block suspicious requests
  blocklist('block bad actors') do |req|
    # Block requests from known bad IPs (configure in environment)
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip)
  end

  # Safelist health check endpoint
  safelist('allow health check') do |req|
    req.path == '/api/v1/health' || req.path == '/up'
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    [
      429,
      headers,
      [
        {
          success: false,
          message: 'Too many requests. Please try again later.',
          retry_after: match_data[:period]
        }.to_json
      ]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |_request|
    [
      403,
      { 'Content-Type' => 'application/json' },
      [
        {
          success: false,
          message: 'Access denied'
        }.to_json
      ]
    ]
  end
end

