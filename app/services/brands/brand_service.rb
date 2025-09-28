module Brands
  class BrandService
    class << self
      def list_brands(pagination: {})
        brands = Brand.includes(:products)
        brands = paginate(brands, pagination)

        {
          brands: brands.map { |brand| BrandSerializer.new(brand).as_json },
          pagination: pagination_meta(brands)
        }
      end

      def find_brand(id)
        brand = Brand.includes(:products).find(id)
        {
          brand: BrandSerializer.new(brand).as_json,
          products_count: brand.products.count
        }
      end

      def create_brand(params)
        brand = Brand.new(params)

        if brand.save
          { success: true, brand: BrandSerializer.new(brand).as_json }
        else
          { success: false, errors: brand.errors.full_messages }
        end
      end

      def update_brand(id, params)
        brand = Brand.find(id)

        if brand.update(params)
          { success: true, brand: BrandSerializer.new(brand).as_json }
        else
          { success: false, errors: brand.errors.full_messages }
        end
      end

      def delete_brand(id)
        brand = Brand.find(id)
        brand.destroy
        { success: true }
      end

      private

      def paginate(brands, pagination)
        page = pagination[:page] || 1
        per_page = pagination[:per_page] || 10
        brands.page(page).per(per_page)
      end

      def pagination_meta(paginated_brands)
        {
          current_page: paginated_brands.current_page,
          total_pages: paginated_brands.total_pages,
          total_count: paginated_brands.total_count,
          per_page: paginated_brands.limit_value
        }
      end
    end
  end
end
