class BrandSerializer
  def initialize(brand)
    @brand = brand
  end

  def as_json
    {
      id: @brand.id,
      name: @brand.name,
      description: @brand.description,
      logo_url: logo_url,
      phones_count: @brand.phones.count,
      created_at: @brand.created_at&.iso8601,
      updated_at: @brand.updated_at&.iso8601
    }
  end

  private

  def logo_url
    @brand.read_attribute(:logo_url)
  end
end
