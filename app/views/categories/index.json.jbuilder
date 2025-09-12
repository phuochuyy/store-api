json.categories @categories do |category|
  json.id category.id
  json.name category.name
  json.description category.description
  json.phones_count category.phones.count
  json.created_at category.created_at
  json.updated_at category.updated_at
end

json.pagination do
  json.current_page @categories.current_page
  json.total_pages @categories.total_pages
  json.total_count @categories.total_count
  json.per_page @categories.limit_value
end
