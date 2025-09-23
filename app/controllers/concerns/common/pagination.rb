module Common::Pagination
  extend ActiveSupport::Concern

  private

  def paginate(collection, page: nil, per_page: nil)
    page = page&.to_i || 1
    per_page = per_page&.to_i || 10
    
    # Limit per_page to prevent abuse
    per_page = [per_page, 100].min
    
    collection.page(page).per(per_page)
  end

  def pagination_meta(paginated_collection)
    {
      current_page: paginated_collection.current_page,
      total_pages: paginated_collection.total_pages,
      total_count: paginated_collection.total_count,
      per_page: paginated_collection.limit_value,
      has_next_page: paginated_collection.next_page.present?,
      has_prev_page: paginated_collection.prev_page.present?
    }
  end
end
