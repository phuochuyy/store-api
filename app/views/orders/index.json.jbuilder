json.orders @orders do |order|
  json.id order.id
  json.customer_name order.customer_name
  json.customer_email order.customer_email
  json.customer_phone order.customer_phone
  json.total_amount order.total_amount
  json.status order.status
  json.created_at order.created_at
  json.updated_at order.updated_at
end

json.pagination do
  json.current_page @orders.current_page
  json.total_pages @orders.total_pages
  json.total_count @orders.total_count
  json.per_page @orders.limit_value
end
