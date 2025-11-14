module Api
  module V1
    class StatisticsController < Api::V1::BaseController
      before_action :authenticate_user!
      before_action :admin_only!

      def dashboard
        stats = {
          total_orders: Order.count,
          total_revenue: Order.sum(:total_amount),
          total_products: Product.count,
          total_customers: User.where(role: 'customer').count
        }

        render_success(stats, 'Dashboard statistics retrieved successfully')
      end

      def inventory
        inventory_stats = {
          low_stock_products: Product.where(stock_quantity: ...10),
          out_of_stock_products: Product.where(stock_quantity: 0),
          total_inventory_value: Product.sum('price * stock_quantity'),
          products_by_brand: Product.joins(:brand).group('brands.name').count,
          products_by_category: Product.joins(:category).group('categories.name').count
        }

        render_success(inventory_stats, 'Inventory statistics retrieved successfully')
      end

      def sales
        date_range = if params[:start_date] && params[:end_date]
                       Date.parse(params[:start_date])..Date.parse(params[:end_date])
                     else
                       30.days.ago..Time.current
                     end

        sales_stats = {
          total_sales: Order.where(created_at: date_range).sum(:total_amount),
          total_orders: Order.where(created_at: date_range).count,
          average_order_value: Order.where(created_at: date_range).average(:total_amount),
          sales_by_day: Order.where(created_at: date_range)
                             .group('DATE(created_at)')
                             .sum(:total_amount),
          top_customers: Order.joins('LEFT JOIN users ON orders.customer_email = users.email')
                              .where(created_at: date_range)
                              .group(:customer_email, :customer_name)
                              .sum(:total_amount)
                              .sort_by { |_, amount| -amount }
                              .first(10)
        }

        render json: sales_stats
      end
    end
  end
end
