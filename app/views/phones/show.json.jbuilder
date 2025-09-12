json.phone do
  json.id @phone.id
  json.name @phone.name
  json.description @phone.description
  json.price @phone.price
  json.stock_quantity @phone.stock_quantity
  json.in_stock @phone.in_stock?
  json.brand do
    json.id @phone.brand.id
    json.name @phone.brand.name
  end
  json.category do
    json.id @phone.category.id
    json.name @phone.category.name
  end
  json.created_at @phone.created_at
  json.updated_at @phone.updated_at
end

json.related_phones @phone.brand.phones.where.not(id: @phone.id).limit(4) do |phone|
  json.id phone.id
  json.name phone.name
  json.price phone.price
  json.stock_quantity phone.stock_quantity
end
