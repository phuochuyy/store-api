json.brand do
  json.id @brand.id
  json.name @brand.name
  json.description @brand.description
  json.products_count @brand.products.count
  json.created_at @brand.created_at
  json.updated_at @brand.updated_at
end

json.products @brand.products.limit(10) do |product|
  json.id product.id
  json.name product.name
  json.price product.price
  json.stock_quantity product.stock_quantity
  json.category do
    json.id product.category.id
    json.name product.category.name
  end
end
