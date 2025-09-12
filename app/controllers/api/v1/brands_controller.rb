class Api::V1::BrandsController < Api::V1::BaseController
  before_action :set_brand, only: [ :show, :update, :destroy ]
  before_action :admin_only!, only: [ :create, :update, :destroy ]

  # GET /api/v1/brands
  def index
    @brands = Brand.includes(:phones)
    @brands = @brands.page(params[:page]).per(params[:per_page] || 10)

    render json: {
      brands: @brands.map { |brand| brand_serializer(brand) },
      pagination: {
        current_page: @brands.current_page,
        total_pages: @brands.total_pages,
        total_count: @brands.total_count,
        per_page: @brands.limit_value
      }
    }
  end

  # GET /api/v1/brands/:id
  def show
    render json: {
      brand: brand_serializer(@brand),
      phones: @brand.phones.limit(10).map { |phone| phone_serializer(phone) }
    }
  end

  # POST /api/v1/brands
  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      render json: {
        message: "Brand created successfully",
        brand: brand_serializer(@brand)
      }, status: :created
    else
      render json: {
        errors: @brand.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/brands/:id
  def update
    if @brand.update(brand_params)
      render json: {
        message: "Brand updated successfully",
        brand: brand_serializer(@brand)
      }
    else
      render json: {
        errors: @brand.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/brands/:id
  def destroy
    @brand.destroy
    render json: { message: "Brand deleted successfully" }
  end

  private

  def set_brand
    @brand = Brand.find(params[:id])
  end

  def brand_params
    params.require(:brand).permit(:name, :description)
  end

  def brand_serializer(brand)
    {
      id: brand.id,
      name: brand.name,
      description: brand.description,
      phones_count: brand.phones.count,
      created_at: brand.created_at,
      updated_at: brand.updated_at
    }
  end

  def phone_serializer(phone)
    {
      id: phone.id,
      name: phone.name,
      price: phone.price,
      stock_quantity: phone.stock_quantity
    }
  end
end
