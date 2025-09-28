class ProductSerializer
  def initialize(product)
    @product = product
  end

  def as_json
    {
      id: @product.id,
      name: @product.name,
      description: @product.description,
      price: @product.price,
      stock_quantity: @product.stock_quantity,
      in_stock: @product.in_stock?,
      image_url: image_url,
      specifications: specifications,
      brand: brand_data,
      category: category_data,
      created_at: @product.created_at&.iso8601,
      updated_at: @product.updated_at&.iso8601
    }
  end

  private

  def image_url
    return nil unless @product.image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(@product.image, only_path: true)
  end

  def specifications
    return {} unless @product.specifications.present?

    if @product.specifications.is_a?(String)
      JSON.parse(@product.specifications)
    else
      @product.specifications
    end
  rescue JSON::ParserError
    {}
  end

  def brand_data
    return nil unless @product.brand

    {
      id: @product.brand.id,
      name: @product.brand.name
    }
  end

  def category_data
    return nil unless @product.category

    {
      id: @product.category.id,
      name: @product.category.name
    }
  end
end
