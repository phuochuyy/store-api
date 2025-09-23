class Categories::CategoryService
  class << self
    def list_categories(pagination: {})
      categories = Category.includes(:phones)
      categories = paginate(categories, pagination)
      
      {
        categories: categories.map { |category| CategorySerializer.new(category).as_json },
        pagination: pagination_meta(categories)
      }
    end

    def find_category(id)
      category = Category.includes(:phones).find(id)
      {
        category: CategorySerializer.new(category).as_json,
        phones_count: category.phones.count
      }
    end

    def create_category(params)
      category = Category.new(params)
      
      if category.save
        { success: true, category: CategorySerializer.new(category).as_json }
      else
        { success: false, errors: category.errors.full_messages }
      end
    end

    def update_category(id, params)
      category = Category.find(id)
      
      if category.update(params)
        { success: true, category: CategorySerializer.new(category).as_json }
      else
        { success: false, errors: category.errors.full_messages }
      end
    end

    def delete_category(id)
      category = Category.find(id)
      category.destroy
      { success: true }
    end

    private

    def paginate(categories, pagination)
      page = pagination[:page] || 1
      per_page = pagination[:per_page] || 10
      categories.page(page).per(per_page)
    end

    def pagination_meta(paginated_categories)
      {
        current_page: paginated_categories.current_page,
        total_pages: paginated_categories.total_pages,
        total_count: paginated_categories.total_count,
        per_page: paginated_categories.limit_value
      }
    end
  end
end
