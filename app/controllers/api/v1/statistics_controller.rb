class Api::V1::StatisticsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_only!

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  # GET /api/v1/statistics/dashboard
  def dashboard
    stats = {
      total_orders: Order.count,
      total_revenue: Order.sum(:total_amount),
      total_phones: Phone.count,
      total_customers: User.where(role: "customer").count,
      orders_by_status: Order.group(:status).count,
      top_selling_phones: OrderItem.joins(:phone)
                                  .group("phones.name")
                                  .sum(:quantity)
                                  .sort_by { |_, quantity| -quantity }
                                  .first(5),
      revenue_by_month: Order.where(created_at: 12.months.ago..Time.current)
                            .group("DATE_FORMAT(created_at, '%Y-%m')")
                            .sum(:total_amount)
    }

    render json: stats
  end

  # GET /api/v1/statistics/inventory
  def inventory
    inventory_stats = {
      low_stock_phones: Phone.where("stock_quantity < ?", 10),
      out_of_stock_phones: Phone.where(stock_quantity: 0),
      total_inventory_value: Phone.sum("price * stock_quantity"),
      phones_by_brand: Phone.joins(:brand).group("brands.name").count,
      phones_by_category: Phone.joins(:category).group("categories.name").count
    }

    render json: inventory_stats
  end

  # GET /api/v1/statistics/sales
  def sales
    date_range = params[:start_date] && params[:end_date] ?
                 Date.parse(params[:start_date])..Date.parse(params[:end_date]) :
                 30.days.ago..Time.current

    sales_stats = {
      total_sales: Order.where(created_at: date_range).sum(:total_amount),
      total_orders: Order.where(created_at: date_range).count,
      average_order_value: Order.where(created_at: date_range).average(:total_amount),
      sales_by_day: Order.where(created_at: date_range)
                        .group("DATE(created_at)")
                        .sum(:total_amount),
      top_customers: Order.joins("LEFT JOIN users ON orders.customer_email = users.email")
                         .where(created_at: date_range)
                         .group(:customer_email, :customer_name)
                         .sum(:total_amount)
                         .sort_by { |_, amount| -amount }
                         .first(10)
    }

    render json: sales_stats
  end

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Token missing" }, status: :unauthorized unless token

    payload = User.decode_jwt(token)
    return render json: { error: "Invalid token" }, status: :unauthorized unless payload

    @current_user = User.find(payload["user_id"])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  def admin_only!
    render json: { error: "Admin access required" }, status: :forbidden unless current_user&.admin?
  end

  def record_not_found
    render json: { error: "Record not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
