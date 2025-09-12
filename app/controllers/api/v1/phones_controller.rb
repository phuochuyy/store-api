class Api::V1::PhonesController < Api::V1::BaseController
  before_action :set_phone, only: [ :show, :update, :destroy ]
  before_action :admin_only!, only: [ :create, :update, :destroy ]

  # GET /api/v1/phones
  def index
    @phones = Phone.includes(:brand, :category)

    # Filter by brand
    if params[:brand_id].present?
      @phones = @phones.where(brand_id: params[:brand_id])
    end

    # Filter by category
    if params[:category_id].present?
      @phones = @phones.where(category_id: params[:category_id])
    end

    # Search by name
    if params[:search].present?
      @phones = @phones.where("name LIKE ?", "%#{params[:search]}%")
    end

    # Filter by price range
    if params[:min_price].present?
      @phones = @phones.where("price >= ?", params[:min_price])
    end

    if params[:max_price].present?
      @phones = @phones.where("price <= ?", params[:max_price])
    end

    # Only show available phones for customers
    unless current_user&.admin?
      @phones = @phones.available
    end

    @phones = @phones.page(params[:page]).per(params[:per_page] || 10)

    render json: {
      phones: @phones.map { |phone| phone_serializer(phone) },
      pagination: {
        current_page: @phones.current_page,
        total_pages: @phones.total_pages,
        total_count: @phones.total_count,
        per_page: @phones.limit_value
      }
    }
  end

  # GET /api/v1/phones/:id
  def show
    render json: {
      phone: phone_serializer(@phone),
      related_phones: @phone.brand.phones.where.not(id: @phone.id).limit(4).map { |p| phone_serializer(p) }
    }
  end

  # POST /api/v1/phones
  def create
    @phone = Phone.new(phone_params)

    if @phone.save
      render json: {
        message: "Phone created successfully",
        phone: phone_serializer(@phone)
      }, status: :created
    else
      render json: {
        error: "Validation failed",
        message: "Phone could not be created",
        errors: @phone.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/phones/:id
  def update
    if @phone.update(phone_params)
      render json: {
        message: "Phone updated successfully",
        phone: phone_serializer(@phone)
      }
    else
      render json: {
        error: "Validation failed",
        message: "Phone could not be updated",
        errors: @phone.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/phones/:id
  def destroy
    @phone.destroy
    render json: { message: "Phone deleted successfully" }
  end

  private

  def set_phone
    @phone = Phone.find(params[:id])
  end

  def phone_params
    params.require(:phone).permit(:name, :description, :price, :stock_quantity, :brand_id, :category_id)
  end

  def phone_serializer(phone)
    {
      id: phone.id,
      name: phone.name,
      description: phone.description,
      price: phone.price,
      stock_quantity: phone.stock_quantity,
      in_stock: phone.in_stock?,
      brand: {
        id: phone.brand.id,
        name: phone.brand.name
      },
      category: {
        id: phone.category.id,
        name: phone.category.name
      },
      created_at: phone.created_at,
      updated_at: phone.updated_at
    }
  end
end
