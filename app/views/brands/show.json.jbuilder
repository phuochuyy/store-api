json.brand do
  json.id @brand.id
  json.name @brand.name
  json.description @brand.description
  json.phones_count @brand.phones.count
  json.created_at @brand.created_at
  json.updated_at @brand.updated_at
end

json.phones @brand.phones.limit(10) do |phone|
  json.id phone.id
  json.name phone.name
  json.price phone.price
  json.stock_quantity phone.stock_quantity
  json.category do
    json.id phone.category.id
    json.name phone.category.name
  end
end
