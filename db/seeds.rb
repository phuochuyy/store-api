# Clear existing data
User.destroy_all
Brand.destroy_all
Category.destroy_all
Phone.destroy_all
Order.destroy_all
OrderItem.destroy_all

puts 'Creating demo data...'

# Create Users
admin_user = User.create!(
  name: 'Admin User',
  email: 'admin@example.com',
  password: 'password',
  password_confirmation: 'password',
  role: 'admin'
)

customer_user = User.create!(
  name: 'John Customer',
  email: 'customer@example.com',
  password: 'password',
  password_confirmation: 'password',
  role: 'customer'
)

puts "Created #{User.count} users"

# Create Brands
brands_data = [
  { name: 'Apple', description: 'Premium smartphones and technology' },
  { name: 'Samsung', description: 'Innovative Android smartphones' },
  { name: 'Google', description: 'Pure Android experience' },
  { name: 'OnePlus', description: 'Never Settle - Flagship killer phones' },
  { name: 'Xiaomi', description: 'Affordable quality smartphones' }
]

brands = brands_data.map do |brand_data|
  Brand.create!(brand_data)
end

puts "Created #{Brand.count} brands"

# Create Categories
categories_data = [
  { name: 'Flagship', description: 'High-end premium smartphones' },
  { name: 'Mid-range', description: 'Balanced performance and price' },
  { name: 'Budget', description: 'Affordable smartphones' },
  { name: 'Gaming', description: 'Phones optimized for gaming' },
  { name: 'Camera', description: 'Phones with exceptional camera quality' }
]

categories = categories_data.map do |category_data|
  Category.create!(category_data)
end

puts "Created #{Category.count} categories"

# Create Phones
phones_data = [
  {
    name: 'iPhone 15 Pro',
    description: 'The most advanced iPhone with titanium design and A17 Pro chip. Features include Pro camera system, Action button, and USB-C connectivity.',
    price: 999.99,
    stock_quantity: 50,
    brand: brands[0], # Apple
    category: categories[0] # Flagship
  },
  {
    name: 'iPhone 15',
    description: 'The latest iPhone with Dynamic Island and USB-C',
    price: 799.99,
    stock_quantity: 75,
    brand: brands[0], # Apple
    category: categories[0] # Flagship
  },
  {
    name: 'Samsung Galaxy S24 Ultra',
    description: 'Premium Android phone with S Pen and advanced AI features',
    price: 1199.99,
    stock_quantity: 30,
    brand: brands[1], # Samsung
    category: categories[0] # Flagship
  },
  {
    name: 'Samsung Galaxy A54',
    description: 'Mid-range smartphone with great camera and performance',
    price: 449.99,
    stock_quantity: 100,
    brand: brands[1], # Samsung
    category: categories[1] # Mid-range
  },
  {
    name: 'Google Pixel 8 Pro',
    description: 'Pure Android with exceptional camera and AI features',
    price: 999.99,
    stock_quantity: 40,
    brand: brands[2], # Google
    category: categories[0] # Flagship
  },
  {
    name: 'Google Pixel 7a',
    description: 'Affordable Pixel with great camera quality',
    price: 499.99,
    stock_quantity: 80,
    brand: brands[2], # Google
    category: categories[1] # Mid-range
  },
  {
    name: 'OnePlus 12',
    description: 'Flagship killer with Snapdragon 8 Gen 3',
    price: 799.99,
    stock_quantity: 60,
    brand: brands[3], # OnePlus
    category: categories[0] # Flagship
  },
  {
    name: 'OnePlus Nord 3',
    description: 'Mid-range phone with flagship features',
    price: 399.99,
    stock_quantity: 90,
    brand: brands[3], # OnePlus
    category: categories[1] # Mid-range
  },
  {
    name: 'Xiaomi 14',
    description: 'Premium Android phone with Leica camera',
    price: 699.99,
    stock_quantity: 70,
    brand: brands[4], # Xiaomi
    category: categories[0] # Flagship
  },
  {
    name: 'Xiaomi Redmi Note 13',
    description: 'Budget-friendly phone with great value',
    price: 199.99,
    stock_quantity: 150,
    brand: brands[4], # Xiaomi
    category: categories[2] # Budget
  },
  {
    name: 'ASUS ROG Phone 8',
    description: 'Gaming smartphone with advanced cooling and performance',
    price: 1099.99,
    stock_quantity: 25,
    brand: Brand.create!(name: 'ASUS', description: 'Gaming and performance devices'),
    category: categories[3] # Gaming
  },
  {
    name: 'Sony Xperia 1 V',
    description: 'Professional camera phone with 4K display',
    price: 1299.99,
    stock_quantity: 20,
    brand: Brand.create!(name: 'Sony', description: 'Premium multimedia devices'),
    category: categories[4] # Camera
  }
]

phones = phones_data.map do |phone_data|
  Phone.create!(phone_data)
end

puts "Created #{Phone.count} phones"

# Create Sample Orders
orders_data = [
  {
    customer_name: 'Alice Johnson',
    customer_email: 'alice@example.com',
    customer_phone: '555-0101',
    total_amount: 0, # Will be calculated
    status: 'confirmed'
  },
  {
    customer_name: 'Bob Smith',
    customer_email: 'bob@example.com',
    customer_phone: '555-0102',
    total_amount: 0, # Will be calculated
    status: 'shipped'
  },
  {
    customer_name: 'Carol Davis',
    customer_email: 'carol@example.com',
    customer_phone: '555-0103',
    total_amount: 0, # Will be calculated
    status: 'delivered'
  },
  {
    customer_name: 'David Wilson',
    customer_email: 'david@example.com',
    customer_phone: '555-0104',
    total_amount: 0, # Will be calculated
    status: 'pending'
  }
]

orders = orders_data.map do |order_data|
  # Remove total_amount from order_data since it will be calculated
  order_data_without_total = order_data.except(:total_amount)
  Order.create!(order_data_without_total)
end

# Create Order Items
order_items_data = [
  # Order 1 - Alice
  { order: orders[0], phone: phones[0], quantity: 1, unit_price: phones[0].price },
  { order: orders[0], phone: phones[2], quantity: 1, unit_price: phones[2].price },

  # Order 2 - Bob
  { order: orders[1], phone: phones[1], quantity: 2, unit_price: phones[1].price },

  # Order 3 - Carol
  { order: orders[2], phone: phones[4], quantity: 1, unit_price: phones[4].price },
  { order: orders[2], phone: phones[6], quantity: 1, unit_price: phones[6].price },

  # Order 4 - David
  { order: orders[3], phone: phones[9], quantity: 3, unit_price: phones[9].price }
]

order_items_data.each do |item_data|
  OrderItem.create!(item_data)
end

# Update order totals
orders.each(&:update_total_amount)

puts "Created #{Order.count} orders with #{OrderItem.count} order items"

puts "\nDemo data created successfully!"
puts '=' * 50
puts 'Login credentials:'
puts 'Admin: admin@example.com / password'
puts 'Customer: customer@example.com / password'
puts '=' * 50
puts 'Total records created:'
puts "- Users: #{User.count}"
puts "- Brands: #{Brand.count}"
puts "- Categories: #{Category.count}"
puts "- Phones: #{Phone.count}"
puts "- Orders: #{Order.count}"
puts "- Order Items: #{OrderItem.count}"
