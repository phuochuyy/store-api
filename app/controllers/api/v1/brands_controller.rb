class Api::V1::BrandsController < Api::V1::BaseController
  before_action :set_brand, only: [ :show, :update, :destroy ]
  before_action :admin_only!, only: [ :create, :update, :destroy ]

  # GET /api/v1/brands
  def index
    @brands = Brand.all
    render json: @brands
  end

  # GET /api/v1/brands/1
  def show
    render json: @brand
  end

  # POST /api/v1/brands
  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      render json: @brand, status: :created
    else
      render json: { errors: @brand.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/brands/1
  def update
    if @brand.update(brand_params)
      render json: @brand
    else
      render json: { errors: @brand.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/brands/1
  def destroy
    @brand.destroy
    head :no_content
  end

  private

  def set_brand
    @brand = Brand.find(params[:id])
  end

  def brand_params
    params.require(:brand).permit(:name, :description)
  end
end
