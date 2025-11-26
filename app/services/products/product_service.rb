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
        products = apply_search_filter(products, filters[:search])
        products = apply_brand_filter(products, filters[:brand_id])
        products = apply_category_filter(products, filters[:category_id])
        products = apply_price_filters(products, filters[:min_price], filters[:max_price])
        apply_stock_filter(products, filters[:in_stock])
      end

      def apply_search_filter(products, search_term)
        return products if search_term.blank?

        products.where('name ILIKE ?', "%#{search_term}%")
      end

      def apply_brand_filter(products, brand_id)
        return products if brand_id.blank?

        products.where(brand_id: brand_id)
      end

      def apply_category_filter(products, category_id)
        return products if category_id.blank?

        products.where(category_id: category_id)
      end

      def apply_price_filters(products, min_price, max_price)
        products = products.where(price: (min_price)..) if min_price.present?
        products = products.where(price: ..(max_price)) if max_price.present?
        products
      end

      def apply_stock_filter(products, in_stock)
        return products unless in_stock == true

        products.where('stock_quantity > 0')
      end

      def apply_search_filters(products, filters)
        products = apply_full_text_search(products, filters[:search])
        products = apply_brand_filter(products, filters[:brand_id])
        products = apply_category_filter(products, filters[:category_id])
        products = apply_price_filters(products, filters[:min_price], filters[:max_price])
        apply_stock_filter(products, filters[:in_stock])
      end

      def apply_full_text_search(products, search_term)
        return products if search_term.blank?

        search_pattern = "%#{search_term}%"
        products.left_joins(:brand, :category).where(
          'products.name ILIKE ? OR products.description ILIKE ? OR brands.name ILIKE ? OR categories.name ILIKE ?',
          search_pattern, search_pattern, search_pattern, search_pattern
        )
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
