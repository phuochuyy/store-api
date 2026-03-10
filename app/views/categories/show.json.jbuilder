json.category do
  json.id @category.id
  json.name @category.name
  json.description @category.description
  json.products_count @category.products.count
  json.created_at @category.created_at
  json.updated_at @category.updated_at
end

json.products @category.products.limit(10) do |product|
  json.id product.id
  json.name product.name
  json.price product.price
  json.stock_quantity product.stock_quantity
  json.brand do
    json.id product.brand.id
    json.name product.brand.name
  end
end
