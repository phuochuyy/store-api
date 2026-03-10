json.brands @brands do |brand|
  json.id brand.id
  json.name brand.name
  json.description brand.description
  json.products_count brand.products.count
  json.created_at brand.created_at
  json.updated_at brand.updated_at
end

json.pagination do
  json.current_page @brands.current_page
  json.total_pages @brands.total_pages
  json.total_count @brands.total_count
  json.per_page @brands.limit_value
end
