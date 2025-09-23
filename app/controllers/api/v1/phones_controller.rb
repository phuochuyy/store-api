class Api::V1::PhonesController < Api::V1::BaseController
  before_action :set_phone, only: [:show, :update, :destroy, :upload_image, :remove_image]
  before_action :authorize_phone, only: [:create, :update, :destroy, :upload_image, :remove_image]

  # GET /api/v1/phones
  def index
    filters = extract_filters
    pagination = extract_pagination
    
    result = Phones::PhoneService.list_phones(filters: filters, pagination: pagination)
    
    render_success(result, "Phones retrieved successfully")
  end

  # GET /api/v1/phones/:id
  def show
    result = Phones::PhoneService.find_phone(@phone.id)
    render_success(result, "Phone retrieved successfully")
  end

  # POST /api/v1/phones
  def create
    validator = PhoneValidator.new(phone_params)
    
    unless validator.valid?
      return render_error("Validation failed", :unprocessable_entity, validator.errors.full_messages)
    end

    result = Phones::PhoneService.create_phone(phone_params)
    
    if result[:success]
      render_success(result[:phone], "Phone created successfully", :created)
    else
      render_error("Phone could not be created", :unprocessable_entity, result[:errors])
    end
  end

  # PATCH/PUT /api/v1/phones/:id
  def update
    validator = PhoneValidator.new(phone_params)
    
    unless validator.valid?
      return render_error("Validation failed", :unprocessable_entity, validator.errors.full_messages)
    end

    result = Phones::PhoneService.update_phone(@phone.id, phone_params)
    
    if result[:success]
      render_success(result[:phone], "Phone updated successfully")
    else
      render_error("Phone could not be updated", :unprocessable_entity, result[:errors])
    end
  end

  # DELETE /api/v1/phones/:id
  def destroy
    result = Phones::PhoneService.delete_phone(@phone.id)
    render_success(nil, "Phone deleted successfully")
  end

  # POST /api/v1/phones/:id/upload_image
  def upload_image
    result = Phones::PhoneService.upload_image(@phone, params[:image])
    
    if result[:success]
      render_success({ image_url: result[:image_url] }, "Image uploaded successfully")
    else
      render_error(result[:error], :bad_request)
    end
  end

  # DELETE /api/v1/phones/:id/remove_image
  def remove_image
    result = Phones::PhoneService.remove_image(@phone)
    render_success(nil, "Image removed successfully")
  end

  private

  def set_phone
    @phone = Phone.find(params[:id])
  end

  def authorize_phone
    action = action_name.to_sym
    result = Auth::AuthenticationService.authorize(current_user, @phone || Phone.new, action)
    
    unless result[:success]
      render_error(result[:error], :forbidden)
    end
  end

  def phone_params
    params.require(:phone).permit(:name, :description, :price, :stock_quantity, :brand_id, :category_id, :specifications)
  end

  def extract_filters
    {
      brand_id: params[:brand_id],
      category_id: params[:category_id],
      search: params[:search],
      min_price: params[:min_price],
      max_price: params[:max_price],
      include_unavailable: current_user&.admin?
    }.compact
  end

  def extract_pagination
    {
      page: params[:page],
      per_page: params[:per_page]
    }.compact
  end
end
