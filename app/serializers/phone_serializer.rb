class PhoneSerializer
  def initialize(phone)
    @phone = phone
  end

  def as_json
    {
      id: @phone.id,
      name: @phone.name,
      description: @phone.description,
      price: @phone.price,
      stock_quantity: @phone.stock_quantity,
      in_stock: @phone.in_stock?,
      image_url: image_url,
      specifications: specifications,
      brand: brand_data,
      category: category_data,
      created_at: @phone.created_at&.iso8601,
      updated_at: @phone.updated_at&.iso8601
    }
  end

  private

  def image_url
    if @phone.image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(@phone.image)
    else
      @phone.read_attribute(:image_url)
    end
  end

  def specifications
    return {} unless @phone.specifications.present?
    
    if @phone.specifications.is_a?(String)
      JSON.parse(@phone.specifications)
    else
      @phone.specifications
    end
  rescue JSON::ParserError
    {}
  end

  def brand_data
    {
      id: @phone.brand.id,
      name: @phone.brand.name
    }
  end

  def category_data
    {
      id: @phone.category.id,
      name: @phone.category.name
    }
  end
end
