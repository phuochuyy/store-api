class Api::V1::PhonesController < Api::V1::BaseController
  before_action :set_phone, only: [ :show, :update, :destroy ]

  # GET /api/v1/phones
  def index
    @phones = Phone.includes(:brand, :category)

    # Filter by brand if specified
    @phones = @phones.where(brand_id: params[:brand_id]) if params[:brand_id].present?

    # Filter by category if specified
    @phones = @phones.where(category_id: params[:category_id]) if params[:category_id].present?

    # Search by name if specified
    @phones = @phones.where("name LIKE ?", "%#{params[:search]}%") if params[:search].present?

    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    @phones = @phones.page(page).per(per_page)

    render json: {
      phones: @phones,
      pagination: {
        current_page: @phones.current_page,
        total_pages: @phones.total_pages,
        total_count: @phones.total_count,
        per_page: @phones.limit_value
      }
    }
  end

  # GET /api/v1/phones/1
  def show
    render json: @phone, include: [ :brand, :category ]
  end

  # POST /api/v1/phones
  def create
    @phone = Phone.new(phone_params)

    if @phone.save
      render json: @phone, status: :created, include: [ :brand, :category ]
    else
      render json: { errors: @phone.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/phones/1
  def update
    if @phone.update(phone_params)
      render json: @phone, include: [ :brand, :category ]
    else
      render json: { errors: @phone.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/phones/1
  def destroy
    @phone.destroy
    head :no_content
  end

  private

  def set_phone
    @phone = Phone.find(params[:id])
  end

  def phone_params
    params.require(:phone).permit(:name, :description, :price, :brand_id, :category_id, :stock_quantity, :image_url, :specifications)
  end
end
