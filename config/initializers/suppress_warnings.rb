# frozen_string_literal: true

# Suppress warnings from third-party gems
# This file suppresses known warnings from gems that haven't been updated yet

if Rails.env.test? || Rails.env.development?
  # Suppress warnings from third-party gems
  # These are known issues in gems that haven't been updated for Ruby 3.4+
  original_warn = Warning.method(:warn)
  
  Warning.define_singleton_method(:warn) do |message, category: nil|
    # Suppress specific warnings from third-party gems
    return if message.include?('URI::RFC3986_PARSER.make_regexp is obsolete') # letter_opener
    return if message.include?('method redefined') && message.include?('lograge') # lograge
    return if message.include?('method redefined') && message.include?('rouge') # rouge
    return if message.include?('previous definition') # method redefined warnings
    return if message.include?('character class has duplicated range') # rouge regex warnings
    
    # Call original warn for all other warnings
    original_warn.call(message, category: category)
  end
end

