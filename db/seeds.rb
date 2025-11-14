# Clear existing data
# Destroy in order to respect foreign key constraints
Coupon.destroy_all
# Destroy payment_histories using SQL since model may not exist
if ActiveRecord::Base.connection.table_exists?('payment_histories')
  ActiveRecord::Base.connection.execute('DELETE FROM payment_histories')
end
Payment.destroy_all
OrderItem.destroy_all
Order.destroy_all
ProductComparisonItem.destroy_all
ProductComparison.destroy_all
ProductWishlist.destroy_all
ProductReview.destroy_all
StockMovement.destroy_all
StockAlert.destroy_all
CartItem.destroy_all
Cart.destroy_all
Notification.destroy_all
UserAddress.destroy_all
User.destroy_all
Brand.destroy_all
Category.destroy_all
Product.destroy_all
Discount.destroy_all
Promotion.destroy_all

Rails.logger.debug 'Creating demo data...'

# Create Users
admin_user = User.create!(
  name: 'Admin User',
  first_name: 'Admin',
  last_name: 'User',
  email: 'admin@example.com',
  password: 'password',
  password_confirmation: 'password',
  role: 'admin'
)

customer_user = User.create!(
  name: 'John Customer',
  first_name: 'John',
  last_name: 'Customer',
  email: 'customer@example.com',
  password: 'password',
  password_confirmation: 'password',
  role: 'customer'
)

# Generate verification tokens for demo users
admin_user.generate_email_verification_token!
customer_user.generate_email_verification_token!

Rails.logger.debug { "Created #{User.count} users" }

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

Rails.logger.debug { "Created #{Brand.count} brands" }

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

Rails.logger.debug { "Created #{Category.count} categories" }

# Create Products
products_data = [
  {
    name: 'iPhone 15 Pro',
    description: 'The most advanced iPhone with titanium design and A17 Pro chip. ' \
                 'Features include Pro camera system, Action button, and USB-C connectivity.',
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

products = products_data.map do |product_data|
  Product.create!(product_data)
end

Rails.logger.debug { "Created #{Product.count} products" }

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
  { order: orders[0], product: products[0], quantity: 1, unit_price: products[0].price },
  { order: orders[0], product: products[2], quantity: 1, unit_price: products[2].price },

  # Order 2 - Bob
  { order: orders[1], product: products[1], quantity: 2, unit_price: products[1].price },

  # Order 3 - Carol
  { order: orders[2], product: products[4], quantity: 1, unit_price: products[4].price },
  { order: orders[2], product: products[6], quantity: 1, unit_price: products[6].price },

  # Order 4 - David
  { order: orders[3], product: products[9], quantity: 3, unit_price: products[9].price }
]

order_items_data.each do |item_data|
  OrderItem.create!(item_data)
end

# Update order totals
orders.each do |order|
  order.update_total_amount rescue nil
end

Rails.logger.debug { "Created #{Order.count} orders with #{OrderItem.count} order items" }

Rails.logger.debug "\nDemo data created successfully!"
Rails.logger.debug '=' * 50
Rails.logger.debug 'Login credentials:'
Rails.logger.debug 'Admin: admin@example.com / password'
Rails.logger.debug 'Customer: customer@example.com / password'
Rails.logger.debug '=' * 50
Rails.logger.debug 'Total records created:'
Rails.logger.debug { "- Users: #{User.count}" }
Rails.logger.debug { "- Brands: #{Brand.count}" }
Rails.logger.debug { "- Categories: #{Category.count}" }
Rails.logger.debug { "- Products: #{Product.count}" }
Rails.logger.debug { "- Orders: #{Order.count}" }
Rails.logger.debug { "- Order Items: #{OrderItem.count}" }

# Load discount and promotion seeds
load Rails.root.join('db/seeds/discounts.rb')

# Load additional sample data
load Rails.root.join('db/seeds/additional_data.rb')

# Load missing tables seeds (coupons, payments, reviews, wishlists, etc.)
load Rails.root.join('db/seeds/missing_tables.rb')
