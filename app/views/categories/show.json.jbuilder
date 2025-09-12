json.category do
  json.id @category.id
  json.name @category.name
  json.description @category.description
  json.phones_count @category.phones.count
  json.created_at @category.created_at
  json.updated_at @category.updated_at
end

json.phones @category.phones.limit(10) do |phone|
  json.id phone.id
  json.name phone.name
  json.price phone.price
  json.stock_quantity phone.stock_quantity
  json.brand do
    json.id phone.brand.id
    json.name phone.brand.name
  end
end
