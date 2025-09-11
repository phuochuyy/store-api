class Api::V1::OrdersController < Api::V1::BaseController
  before_action :set_order, only: [ :show, :update, :destroy ]

  # GET /api/v1/orders
  def index
    @orders = Order.includes(:order_items, :phones)

    # Filter by status if specified
    @orders = @orders.where(status: params[:status]) if params[:status].present?

    # Filter by customer email if specified
    @orders = @orders.where("customer_email LIKE ?", "%#{params[:customer_email]}%") if params[:customer_email].present?

    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    @orders = @orders.page(page).per(per_page)

    render json: {
      orders: @orders,
      pagination: {
        current_page: @orders.current_page,
        total_pages: @orders.total_pages,
        total_count: @orders.total_count,
        per_page: @orders.limit_value
      }
    }
  end

  # GET /api/v1/orders/1
  def show
    render json: @order, include: { order_items: { include: :phone } }
  end

  # POST /api/v1/orders
  def create
    @order = Order.new(order_params)

    if @order.save
      render json: @order, status: :created, include: { order_items: { include: :phone } }
    else
      render json: { errors: @order.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/orders/1
  def update
    if @order.update(order_params)
      render json: @order, include: { order_items: { include: :phone } }
    else
      render json: { errors: @order.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/orders/1
  def destroy
    @order.destroy
    head :no_content
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:customer_name, :customer_email, :customer_phone, :total_amount, :status)
  end
end
