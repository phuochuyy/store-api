class CategorySerializer
  def initialize(category)
    @category = category
  end

  def as_json
    {
      id: @category.id,
      name: @category.name,
      description: @category.description,
      icon_url: icon_url,
      products_count: @category.products.count,
      created_at: @category.created_at&.iso8601,
      updated_at: @category.updated_at&.iso8601
    }
  end

  private

  def icon_url
    @category.read_attribute(:icon_url)
  end
end
