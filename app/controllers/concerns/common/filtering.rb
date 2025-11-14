module Common
  module Filtering
    extend ActiveSupport::Concern

    included do

    end

    private

    def apply_filters(collection, allowed_filters)
      allowed_filters.each do |filter_key, filter_value|
        next if filter_value.blank?

        collection = case filter_key
                     when :search
                       apply_search(collection, filter_value)
                     when :date_range
                       apply_date_range(collection, filter_value)
                     when :price_range
                       apply_price_range(collection, filter_value)
                     else
                       collection.where(filter_key => filter_value)
                     end
      end

      collection
    end

    def apply_search(collection, _search_term)
      # This should be overridden in specific controllers
      collection
    end

    def apply_date_range(collection, date_range)
      return collection unless date_range.is_a?(Hash)

      start_date = date_range[:start_date]
      end_date = date_range[:end_date]

      collection = collection.where(created_at: start_date..) if start_date
      collection = collection.where(created_at: ..end_date) if end_date

      collection
    end

    def apply_price_range(collection, price_range)
      return collection unless price_range.is_a?(Hash)

      min_price = price_range[:min_price]
      max_price = price_range[:max_price]

      collection = collection.where(price: min_price..) if min_price
      collection = collection.where(price: ..max_price) if max_price

      collection
    end
  end
end
