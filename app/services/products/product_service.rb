module Products
  class ProductService
    class << self
      def list_products(filters: {}, pagination: {})
        products = Product.includes(:brand, :category)
        products = apply_filters(products, filters)
        products = paginate(products, pagination)

        {
          products: products.map { |product| ProductSerializer.new(product).as_json },
          pagination: pagination_meta(products)
        }
      end

      def find_product(id)
        product = Product.includes(:brand, :category).find(id)
        {
          product: ProductSerializer.new(product).as_json,
          related_products: get_related_products(product)
        }
      end

      def search_products(filters: {}, pagination: {})
        products = Product.includes(:brand, :category)
        products = apply_search_filters(products, filters)
        products = paginate(products, pagination)

        {
          products: products.map { |product| ProductSerializer.new(product).as_json },
          pagination: pagination_meta(products),
          search_query: filters[:search]
        }
      end

      def create_product(params)
        product = Product.new(params)

        if product.save
          { success: true, product: ProductSerializer.new(product).as_json }
        else
          { success: false, error: product.errors.full_messages.join(', ') }
        end
      end

      def update_product(id, params)
        product = Product.find(id)

        if product.update(params)
          { success: true, product: ProductSerializer.new(product).as_json }
        else
          { success: false, error: product.errors.full_messages.join(', ') }
        end
      end

      def delete_product(id)
        product = Product.find(id)
        if product.order_items.exists?
          return { success: false,
                   error: 'Cannot delete product with existing order items' }
        end

        product.destroy
        { success: true }
      end

      private

      def apply_filters(products, filters)
        products = products.where('name ILIKE ?', "%#{filters[:search]}%") if filters[:search].present?
        products = products.where(brand_id: filters[:brand_id]) if filters[:brand_id].present?
        products = products.where(category_id: filters[:category_id]) if filters[:category_id].present?
        products = products.where(price: (filters[:min_price])..) if filters[:min_price].present?
        products = products.where(price: ..(filters[:max_price])) if filters[:max_price].present?
        products = products.where('stock_quantity > 0') if filters[:in_stock] == true
        products
      end

      def apply_search_filters(products, filters)
        if filters[:search].present?
          search_term = "%#{filters[:search]}%"
          products = products.left_joins(:brand, :category).where(
            'products.name ILIKE ? OR products.description ILIKE ? OR brands.name ILIKE ? OR categories.name ILIKE ?',
            search_term, search_term, search_term, search_term
          )
        end
        products = products.where(brand_id: filters[:brand_id]) if filters[:brand_id].present?
        products = products.where(category_id: filters[:category_id]) if filters[:category_id].present?
        products = products.where(price: (filters[:min_price])..) if filters[:min_price].present?
        products = products.where(price: ..(filters[:max_price])) if filters[:max_price].present?
        products = products.where('stock_quantity > 0') if filters[:in_stock] == true
        products
      end

      def paginate(products, pagination)
        page = pagination[:page] || 1
        per_page = pagination[:per_page] || 10
        products.page(page).per(per_page)
      end

      def pagination_meta(products)
        {
          current_page: products.current_page,
          total_pages: products.total_pages,
          total_count: products.total_count,
          per_page: products.limit_value
        }
      end

      def get_related_products(product)
        Product.where(category: product.category)
               .where.not(id: product.id)
               .limit(4)
               .map { |p| ProductSerializer.new(p).as_json }
      end
    end
  end
end
