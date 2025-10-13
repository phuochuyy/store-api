# frozen_string_literal: true

module StockAlerts
  class StockMonitoringRecommendationService
    class << self
      # Calculate recommended quantity for a product
      # @param product [Product] Product to calculate for
      # @return [Integer] Recommended quantity
      def calculate_recommended_quantity(product)
        return 0 unless product

        base_quantity = calculate_base_quantity(product)
        adjust_for_seasonality(product, base_quantity)
      end

      # Get reorder recommendations
      # @param limit [Integer] Maximum number of recommendations
      # @return [Array<Hash>] Reorder recommendations
      def get_reorder_recommendations(limit = 50)
        recommendations = []

        Product.includes(:category, :brand).find_each do |product|
          next unless needs_reorder?(product)

          recommended_qty = calculate_recommended_quantity(product)
          next if recommended_qty <= 0

          recommendations << {
            product_id: product.id,
            product_name: product.name,
            current_stock: product.stock_quantity,
            recommended_quantity: recommended_qty,
            urgency: calculate_urgency(product),
            category: product.category&.name,
            brand: product.brand&.name
          }
        end

        recommendations.sort_by { |rec| -rec[:urgency] }.first(limit)
      end

      # Get stock level recommendations
      # @param product [Product] Product to analyze
      # @return [Hash] Stock level recommendations
      def get_stock_level_recommendations(product)
        return {} unless product

        {
          current_stock: product.stock_quantity,
          recommended_minimum: calculate_minimum_stock(product),
          recommended_maximum: calculate_maximum_stock(product),
          reorder_point: calculate_reorder_point(product),
          urgency_level: calculate_urgency_level(product),
          recommendations: generate_recommendations(product)
        }
      end

      private

      def calculate_base_quantity(product)
        # Base calculation on average monthly sales
        monthly_sales = calculate_monthly_sales(product)
        safety_stock = (monthly_sales * 0.2).ceil # 20% safety stock
        monthly_sales + safety_stock
      end

      def calculate_monthly_sales(product)
        # This would typically query order history
        # For now, return a default based on product type
        case product.category&.name&.downcase
        when 'electronics'
          10
        when 'clothing'
          25
        when 'books'
          15
        else
          20
        end
      end

      def adjust_for_seasonality(product, base_quantity)
        # Simple seasonality adjustment
        current_month = Time.current.month
        seasonal_multiplier = case current_month
                              when 11, 12 # Holiday season
                                1.5
                              when 6, 7, 8 # Summer
                                1.2
                              else
                                1.0
                              end

        (base_quantity * seasonal_multiplier).ceil
      end

      def needs_reorder?(product)
        product.stock_quantity <= calculate_reorder_point(product)
      end

      def calculate_minimum_stock(product)
        monthly_sales = calculate_monthly_sales(product)
        (monthly_sales * 0.1).ceil # 10% of monthly sales
      end

      def calculate_maximum_stock(product)
        monthly_sales = calculate_monthly_sales(product)
        (monthly_sales * 2.0).ceil # 2 months of sales
      end

      def calculate_reorder_point(product)
        monthly_sales = calculate_monthly_sales(product)
        (monthly_sales * 0.3).ceil # 30% of monthly sales
      end

      def calculate_urgency(product)
        current_stock = product.stock_quantity
        reorder_point = calculate_reorder_point(product)

        if current_stock == 0
          100 # Critical
        elsif current_stock <= reorder_point * 0.5
          80 # High
        elsif current_stock <= reorder_point
          60 # Medium
        else
          20 # Low
        end
      end

      def calculate_urgency_level(product)
        urgency = calculate_urgency(product)
        case urgency
        when 80..100
          'critical'
        when 60..79
          'high'
        when 40..59
          'medium'
        else
          'low'
        end
      end

      def generate_recommendations(product)
        recommendations = []
        current_stock = product.stock_quantity
        reorder_point = calculate_reorder_point(product)

        if current_stock == 0
          recommendations << 'Immediate reorder required - out of stock'
        elsif current_stock <= reorder_point * 0.5
          recommendations << 'Urgent reorder needed - stock critically low'
        elsif current_stock <= reorder_point
          recommendations << 'Reorder recommended - approaching reorder point'
        end

        recommendations
      end
    end
  end
end
