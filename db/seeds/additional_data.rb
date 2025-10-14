# Additional Sample Data Seeds
Rails.logger.debug 'Creating additional sample data...'

# Create more users with different roles and profiles
additional_users = [
  {
    name: 'Sarah Johnson',
    email: 'sarah.johnson@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'customer'
  },
  {
    name: 'Mike Chen',
    email: 'mike.chen@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'customer'
  },
  {
    name: 'Emily Davis',
    email: 'emily.davis@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'customer'
  },
  {
    name: 'Alex Rodriguez',
    email: 'alex.rodriguez@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'customer'
  },
  {
    name: 'Lisa Wang',
    email: 'lisa.wang@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'customer'
  },
  {
    name: 'Store Manager',
    email: 'manager@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'admin'
  }
]

additional_users.each do |user_data|
  user = User.create!(user_data)
  user.generate_email_verification_token!
  Rails.logger.debug { "Created user: #{user.name} (#{user.email})" }
end

Rails.logger.debug { "Total users created: #{User.count}" }

# Create more brands
additional_brands = [
  { name: 'Huawei', description: 'Innovative technology and premium smartphones' },
  { name: 'Oppo', description: 'Camera-focused smartphones with innovative features' },
  { name: 'Vivo', description: 'Music and camera optimized smartphones' },
  { name: 'Realme', description: 'Youth-focused affordable smartphones' },
  { name: 'Nothing', description: 'Transparent design and unique aesthetics' },
  { name: 'Fairphone', description: 'Sustainable and repairable smartphones' }
]

additional_brands.each do |brand_data|
  Brand.create!(brand_data)
end

Rails.logger.debug { "Total brands created: #{Brand.count}" }

# Create more categories
additional_categories = [
  { name: 'Foldable', description: 'Innovative foldable smartphones' },
  { name: 'Rugged', description: 'Durable phones for outdoor activities' },
  { name: 'Business', description: 'Professional phones with security features' },
  { name: 'Student', description: 'Affordable phones for students' },
  { name: 'Senior', description: 'Easy-to-use phones for seniors' },
  { name: 'Accessibility', description: 'Phones with accessibility features' }
]

additional_categories.each do |category_data|
  Category.create!(category_data)
end

Rails.logger.debug { "Total categories created: #{Category.count}" }

# Create more products with diverse pricing and features
additional_products = [
  # Foldable phones
  {
    name: 'Samsung Galaxy Z Fold 5',
    description: 'Premium foldable smartphone with large inner display and S Pen support',
    price: 1799.99,
    stock_quantity: 15,
    brand: Brand.find_by(name: 'Samsung'),
    category: Category.find_by(name: 'Foldable')
  },
  {
    name: 'Google Pixel Fold',
    description: 'Google\'s first foldable with pure Android experience',
    price: 1799.99,
    stock_quantity: 12,
    brand: Brand.find_by(name: 'Google'),
    category: Category.find_by(name: 'Foldable')
  },

  # Gaming phones
  {
    name: 'RedMagic 9 Pro',
    description: 'Gaming phone with active cooling and 120Hz display',
    price: 649.99,
    stock_quantity: 35,
    brand: Brand.create!(name: 'RedMagic', description: 'Gaming smartphones'),
    category: Category.find_by(name: 'Gaming')
  },
  {
    name: 'Black Shark 5 Pro',
    description: 'Gaming phone with magnetic triggers and fast charging',
    price: 599.99,
    stock_quantity: 28,
    brand: Brand.create!(name: 'Black Shark', description: 'Gaming devices'),
    category: Category.find_by(name: 'Gaming')
  },

  # Business phones
  {
    name: 'Samsung Galaxy S24 Ultra Business',
    description: 'Enterprise-grade security with Knox and business features',
    price: 1299.99,
    stock_quantity: 20,
    brand: Brand.find_by(name: 'Samsung'),
    category: Category.find_by(name: 'Business')
  },
  {
    name: 'iPhone 15 Pro Business',
    description: 'Professional iPhone with enhanced security and productivity features',
    price: 1099.99,
    stock_quantity: 25,
    brand: Brand.find_by(name: 'Apple'),
    category: Category.find_by(name: 'Business')
  },

  # Student phones
  {
    name: 'Samsung Galaxy A15',
    description: 'Affordable smartphone perfect for students',
    price: 199.99,
    stock_quantity: 200,
    brand: Brand.find_by(name: 'Samsung'),
    category: Category.find_by(name: 'Student')
  },
  {
    name: 'iPhone SE (3rd Gen)',
    description: 'Compact iPhone with A15 Bionic chip, great for students',
    price: 429.99,
    stock_quantity: 150,
    brand: Brand.find_by(name: 'Apple'),
    category: Category.find_by(name: 'Student')
  },

  # Rugged phones
  {
    name: 'Samsung Galaxy XCover 6 Pro',
    description: 'Rugged smartphone for outdoor and industrial use',
    price: 499.99,
    stock_quantity: 40,
    brand: Brand.find_by(name: 'Samsung'),
    category: Category.find_by(name: 'Rugged')
  },
  {
    name: 'CAT S75',
    description: 'Ultra-rugged phone with thermal camera and satellite messaging',
    price: 599.99,
    stock_quantity: 30,
    brand: Brand.create!(name: 'CAT', description: 'Rugged mobile devices'),
    category: Category.find_by(name: 'Rugged')
  },

  # Camera-focused phones
  {
    name: 'Huawei P60 Pro',
    description: 'Professional camera phone with variable aperture',
    price: 899.99,
    stock_quantity: 45,
    brand: Brand.find_by(name: 'Huawei'),
    category: Category.find_by(name: 'Camera')
  },
  {
    name: 'Oppo Find X6 Pro',
    description: 'Triple camera system with Hasselblad tuning',
    price: 799.99,
    stock_quantity: 38,
    brand: Brand.find_by(name: 'Oppo'),
    category: Category.find_by(name: 'Camera')
  },

  # Unique design phones
  {
    name: 'Nothing Phone (2)',
    description: 'Transparent design with Glyph interface and clean Android',
    price: 599.99,
    stock_quantity: 60,
    brand: Brand.find_by(name: 'Nothing'),
    category: Category.find_by(name: 'Flagship')
  },
  {
    name: 'Fairphone 5',
    description: 'Sustainable smartphone with 5-year warranty and repairable design',
    price: 699.99,
    stock_quantity: 25,
    brand: Brand.find_by(name: 'Fairphone'),
    category: Category.find_by(name: 'Budget')
  }
]

additional_products.each do |product_data|
  Product.create!(product_data)
end

Rails.logger.debug { "Total products created: #{Product.count}" }

# Create more realistic orders with different statuses and scenarios
customers = User.where(role: 'customer')
products = Product.all

# Create orders for different customers
order_scenarios = [
  {
    customer: customers[0], # Sarah Johnson
    items: [
      { product: products.sample, quantity: 1 },
      { product: products.sample, quantity: 2 }
    ],
    status: 'delivered',
    customer_name: 'Sarah Johnson',
    customer_email: 'sarah.johnson@example.com',
    customer_phone: '+1-555-0105'
  },
  {
    customer: customers[1], # Mike Chen
    items: [
      { product: products.sample, quantity: 1 }
    ],
    status: 'shipped',
    customer_name: 'Mike Chen',
    customer_email: 'mike.chen@example.com',
    customer_phone: '+1-555-0106'
  },
  {
    customer: customers[2], # Emily Davis
    items: [
      { product: products.sample, quantity: 3 },
      { product: products.sample, quantity: 1 }
    ],
    status: 'confirmed',
    customer_name: 'Emily Davis',
    customer_email: 'emily.davis@example.com',
    customer_phone: '+1-555-0107'
  },
  {
    customer: customers[3], # Alex Rodriguez
    items: [
      { product: products.sample, quantity: 1 }
    ],
    status: 'pending',
    customer_name: 'Alex Rodriguez',
    customer_email: 'alex.rodriguez@example.com',
    customer_phone: '+1-555-0108'
  },
  {
    customer: customers[4], # Lisa Wang
    items: [
      { product: products.sample, quantity: 2 },
      { product: products.sample, quantity: 1 },
      { product: products.sample, quantity: 1 }
    ],
    status: 'cancelled',
    customer_name: 'Lisa Wang',
    customer_email: 'lisa.wang@example.com',
    customer_phone: '+1-555-0109'
  }
]

order_scenarios.each do |scenario|
  order = Order.create!(
    customer_name: scenario[:customer_name],
    customer_email: scenario[:customer_email],
    customer_phone: scenario[:customer_phone],
    status: scenario[:status]
  )

  scenario[:items].each do |item|
    OrderItem.create!(
      order: order,
      product: item[:product],
      quantity: item[:quantity],
      unit_price: item[:product].price
    )
  end

  order.update_total_amount
  Rails.logger.debug { "Created order for #{scenario[:customer_name]} with status: #{scenario[:status]}" }
end

Rails.logger.debug { "Total orders created: #{Order.count}" }
Rails.logger.debug { "Total order items created: #{OrderItem.count}" }

# Create shopping carts for some users
cart_users = customers.limit(3)
cart_users.each do |user|
  cart = Cart.create!(
    user: user,
    session_id: SecureRandom.uuid,
    status: 'active'
  )

  # Add random products to cart
  random_products = products.sample(rand(1..4))
  random_products.each do |product|
    CartItem.create!(
      cart: cart,
      product: product,
      quantity: rand(1..3),
      unit_price: product.price
    )
  end

  cart.calculate_total_amount
  Rails.logger.debug { "Created cart for #{user.name} with #{cart.cart_items.count} items" }
end

Rails.logger.debug { "Total carts created: #{Cart.count}" }
Rails.logger.debug { "Total cart items created: #{CartItem.count}" }

# Create notifications for users
notification_types = %w[
  order_confirmed
  order_shipped
  order_delivered
  price_drop
  product_available
  promotion
  stock_alert
  system_alert
]

customers.each do |user|
  # Create 2-5 random notifications per user
  rand(2..5).times do
    Notification.create!(
      user: user,
      title: notification_types.sample.humanize.to_s,
      message: "This is a sample notification for #{user.name}",
      notification_type: notification_types.sample,
      read: [true, false].sample,
      metadata: {
        'order_id' => Order.all.sample&.id,
        'product_id' => Product.all.sample&.id
      }.compact
    )
  end
end

Rails.logger.debug { "Total notifications created: #{Notification.count}" }

# Create stock alerts for low stock products
low_stock_products = Product.where(stock_quantity: ...30)
low_stock_products.each do |product|
  StockAlert.create!(
    product: product,
    threshold: 30,
    current_stock: product.stock_quantity,
    status: 'active',
    alert_type: 'low_stock',
    triggered_at: Time.current,
    message: "Product #{product.name} is running low on stock (#{product.stock_quantity} remaining)"
  )
end

Rails.logger.debug { "Total stock alerts created: #{StockAlert.count}" }

# Create payment methods
payment_methods_data = [
  {
    name: 'Credit Card',
    description: 'Visa, MasterCard, American Express',
    is_active: true,
    gateway_type: 'stripe',
    processing_fee_percentage: 2.9,
    processing_fee_fixed: 0.30,
    gateway_config: {
      'stripe_enabled' => true,
      'paypal_enabled' => false,
      'requires_cvv' => true
    }
  },
  {
    name: 'PayPal',
    description: 'Pay with your PayPal account',
    is_active: true,
    gateway_type: 'paypal',
    processing_fee_percentage: 3.4,
    processing_fee_fixed: 0.35,
    gateway_config: {
      'stripe_enabled' => false,
      'paypal_enabled' => true,
      'requires_cvv' => false
    }
  },
  {
    name: 'Bank Transfer',
    description: 'Direct bank transfer',
    is_active: true,
    gateway_type: 'bank_transfer',
    processing_fee_percentage: 0.0,
    processing_fee_fixed: 5.00,
    gateway_config: {
      'stripe_enabled' => false,
      'paypal_enabled' => false,
      'requires_cvv' => false,
      'processing_days' => 3
    }
  },
  {
    name: 'Cash on Delivery',
    description: 'Pay when you receive your order',
    is_active: true,
    gateway_type: 'cash_on_delivery',
    processing_fee_percentage: 0.0,
    processing_fee_fixed: 0.0,
    gateway_config: {
      'stripe_enabled' => false,
      'paypal_enabled' => false,
      'requires_cvv' => false,
      'delivery_fee' => 5.00
    }
  }
]

payment_methods_data.each do |pm_data|
  PaymentMethod.find_or_create_by(name: pm_data[:name]) do |pm|
    pm.assign_attributes(pm_data)
  end
end

Rails.logger.debug { "Total payment methods created: #{PaymentMethod.count}" }

# Create some sample payments (commented out due to PaymentHistory dependency)
# orders_with_payments = Order.where(status: ['delivered', 'shipped', 'confirmed']).limit(5)
# payment_methods = PaymentMethod.all

# orders_with_payments.each do |order|
#   payment_method = payment_methods.sample

#   Payment.create!(
#     order: order,
#     payment_method: payment_method,
#     amount: order.total_amount,
#     status: ['completed', 'pending', 'failed'].sample,
#     transaction_id: "TXN_#{SecureRandom.hex(8).upcase}",
#     currency: 'USD',
#     metadata: {
#       'card_last_four' => rand(1000..9999).to_s,
#       'card_brand' => ['visa', 'mastercard', 'amex'].sample,
#       'payment_processor' => payment_method.name.downcase.gsub(' ', '_')
#     }
#   )
# end

Rails.logger.debug { "Total payments created: #{Payment.count}" }

Rails.logger.debug 'Additional sample data created successfully!'
Rails.logger.debug '=' * 60
Rails.logger.debug 'SUMMARY OF ADDITIONAL DATA:'
Rails.logger.debug { "- Users: #{User.count} total" }
Rails.logger.debug { "- Brands: #{Brand.count} total" }
Rails.logger.debug { "- Categories: #{Category.count} total" }
Rails.logger.debug { "- Products: #{Product.count} total" }
Rails.logger.debug { "- Orders: #{Order.count} total" }
Rails.logger.debug { "- Order Items: #{OrderItem.count} total" }
Rails.logger.debug { "- Carts: #{Cart.count} total" }
Rails.logger.debug { "- Cart Items: #{CartItem.count} total" }
Rails.logger.debug { "- Notifications: #{Notification.count} total" }
Rails.logger.debug { "- Stock Alerts: #{StockAlert.count} total" }
Rails.logger.debug { "- Payment Methods: #{PaymentMethod.count} total" }
Rails.logger.debug { "- Payments: #{Payment.count} total" }
Rails.logger.debug '=' * 60
