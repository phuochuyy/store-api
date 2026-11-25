# frozen_string_literal: true

# Masks sensitive values in Sentry events and breadcrumbs before they leave the app.
#
# The SDK filters only top-level keys, and only for generic terms (auth, token, password...).
# This applies the app's own filter_parameters, the list that already keeps secrets out of the
# Rails logs (passw, email, token, secret, cvv...), at any depth: { user: { password: } } is
# caught too. Request bodies and query strings reach Sentry only when config.data_collection
# collects them (off by default), but extra data and breadcrumbs always do.
module SentryScrubber
  MASK = '[FILTERED]'
  # Header names rather than params, so not in filter_parameters, but never worth sending.
  EXTRA_TERMS = %i[authorization cookie].freeze

  class << self
    def scrub_event(event, _hint = nil)
      scrub_request(event.request) if event.request
      event.extra = scrub(event.extra)
      event.contexts = scrub(event.contexts)
      event
    end

    def scrub_breadcrumb(breadcrumb, _hint = nil)
      breadcrumb.data = scrub(breadcrumb.data)
      breadcrumb
    end

    private

    def scrub_request(request)
      request.data = scrub(request.data)
      request.query_string = scrub_query(request.query_string)
      request.headers = scrub(request.headers)
      request.cookies = scrub(request.cookies)
    end

    # The SDK hands over the query as a hash of params; older versions used a raw string.
    def scrub_query(query)
      return scrub(query) unless query.is_a?(String)

      Rack::Utils.build_nested_query(scrub(Rack::Utils.parse_nested_query(query)))
    end

    def scrub(value)
      value.is_a?(Hash) ? filter.filter(value) : value
    end

    def filter
      @filter ||= ActiveSupport::ParameterFilter.new(
        Rails.application.config.filter_parameters + EXTRA_TERMS, mask: MASK
      )
    end
  end
end
