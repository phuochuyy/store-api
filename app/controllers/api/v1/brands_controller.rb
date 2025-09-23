class Api::V1::BrandsController < Api::V1::BaseController
  before_action :set_brand, only: [:show, :update, :destroy]
  before_action :authorize_brand, only: [:create, :update, :destroy]

  # GET /api/v1/brands
  def index
    pagination = extract_pagination
    result = Brands::BrandService.list_brands(pagination: pagination)
    
    render_success(result, "Brands retrieved successfully")
  end

  # GET /api/v1/brands/:id
  def show
    result = Brands::BrandService.find_brand(@brand.id)
    render_success(result, "Brand retrieved successfully")
  end

  # POST /api/v1/brands
  def create
    validator = BrandValidator.new(brand_params)
    
    unless validator.valid?
      return render_error("Validation failed", :unprocessable_entity, validator.errors.full_messages)
    end

    result = Brands::BrandService.create_brand(brand_params)
    
    if result[:success]
      render_success(result[:brand], "Brand created successfully", :created)
    else
      render_error("Brand could not be created", :unprocessable_entity, result[:errors])
    end
  end

  # PATCH/PUT /api/v1/brands/:id
  def update
    validator = BrandValidator.new(brand_params)
    
    unless validator.valid?
      return render_error("Validation failed", :unprocessable_entity, validator.errors.full_messages)
    end

    result = Brands::BrandService.update_brand(@brand.id, brand_params)
    
    if result[:success]
      render_success(result[:brand], "Brand updated successfully")
    else
      render_error("Brand could not be updated", :unprocessable_entity, result[:errors])
    end
  end

  # DELETE /api/v1/brands/:id
  def destroy
    result = Brands::BrandService.delete_brand(@brand.id)
    render_success(nil, "Brand deleted successfully")
  end

  private

  def set_brand
    @brand = Brand.find(params[:id])
  end

  def authorize_brand
    action = action_name.to_sym
    result = Auth::AuthenticationService.authorize(current_user, @brand || Brand.new, action)
    
    unless result[:success]
      render_error(result[:error], :forbidden)
    end
  end

  def brand_params
    params.require(:brand).permit(:name, :description)
  end

  def extract_pagination
    {
      page: params[:page],
      per_page: params[:per_page]
    }.compact
  end
end
