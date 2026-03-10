json.order do
  json.id @order.id
  json.customer_name @order.customer_name
  json.customer_email @order.customer_email
  json.customer_phone @order.customer_phone
  json.total_amount @order.total_amount
  json.status @order.status
  json.created_at @order.created_at
  json.updated_at @order.updated_at
end

json.order_items @order.order_items do |item|
  json.id item.id
  json.product do
    json.id item.product.id
    json.name item.product.name
    json.price item.product.price
  end
  json.quantity item.quantity
  json.unit_price item.unit_price
  json.total_price item.total_price
end
