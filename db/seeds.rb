# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create Brands
brands = [
  { name: "Apple", description: "Premium smartphones and technology products" },
  { name: "Samsung", description: "Innovative Android smartphones and electronics" },
  { name: "Google", description: "Pixel smartphones with pure Android experience" },
  { name: "OnePlus", description: "Flagship killer smartphones" },
  { name: "Xiaomi", description: "Affordable smartphones with great features" }
]

brands.each do |brand_data|
  Brand.find_or_create_by!(name: brand_data[:name]) do |brand|
    brand.description = brand_data[:description]
  end
end

# Create Categories
categories = [
  { name: "Flagship", description: "High-end smartphones with premium features" },
  { name: "Mid-range", description: "Balanced smartphones with good performance" },
  { name: "Budget", description: "Affordable smartphones for everyday use" },
  { name: "Gaming", description: "Smartphones optimized for gaming" },
  { name: "Camera", description: "Smartphones with advanced camera features" }
]

categories.each do |category_data|
  Category.find_or_create_by!(name: category_data[:name]) do |category|
    category.description = category_data[:description]
  end
end

# Create Phones
phones = [
  {
    name: "iPhone 15 Pro",
    description: "Latest flagship iPhone with titanium design and A17 Pro chip",
    price: 999.99,
    brand: Brand.find_by(name: "Apple"),
    category: Category.find_by(name: "Flagship"),
    stock_quantity: 50,
    image_url: "https://example.com/iphone15pro.jpg",
    specifications: "6.1-inch Super Retina XDR display, A17 Pro chip, 48MP main camera, Titanium design"
  },
  {
    name: "Samsung Galaxy S24 Ultra",
    description: "Premium Android smartphone with S Pen and advanced AI features",
    price: 1199.99,
    brand: Brand.find_by(name: "Samsung"),
    category: Category.find_by(name: "Flagship"),
    stock_quantity: 30,
    image_url: "https://example.com/galaxy-s24-ultra.jpg",
    specifications: "6.8-inch Dynamic AMOLED 2X, Snapdragon 8 Gen 3, 200MP camera, S Pen included"
  },
  {
    name: "Google Pixel 8 Pro",
    description: "AI-powered smartphone with exceptional camera capabilities",
    price: 899.99,
    brand: Brand.find_by(name: "Google"),
    category: Category.find_by(name: "Camera"),
    stock_quantity: 40,
    image_url: "https://example.com/pixel8pro.jpg",
    specifications: "6.7-inch LTPO OLED, Google Tensor G3, 50MP main camera, Magic Eraser"
  },
  {
    name: "OnePlus 12",
    description: "Flagship killer with Snapdragon 8 Gen 3 and fast charging",
    price: 799.99,
    brand: Brand.find_by(name: "OnePlus"),
    category: Category.find_by(name: "Flagship"),
    stock_quantity: 25,
    image_url: "https://example.com/oneplus12.jpg",
    specifications: "6.82-inch LTPO AMOLED, Snapdragon 8 Gen 3, 50MP camera, 100W SuperVOOC"
  },
  {
    name: "Xiaomi Redmi Note 13 Pro",
    description: "Mid-range smartphone with great value for money",
    price: 299.99,
    brand: Brand.find_by(name: "Xiaomi"),
    category: Category.find_by(name: "Mid-range"),
    stock_quantity: 100,
    image_url: "https://example.com/redmi-note13pro.jpg",
    specifications: "6.67-inch AMOLED, Snapdragon 7s Gen 2, 200MP camera, 67W fast charging"
  }
]

phones.each do |phone_data|
  Phone.find_or_create_by!(name: phone_data[:name]) do |phone|
    phone.description = phone_data[:description]
    phone.price = phone_data[:price]
    phone.brand = phone_data[:brand]
    phone.category = phone_data[:category]
    phone.stock_quantity = phone_data[:stock_quantity]
    phone.image_url = phone_data[:image_url]
    phone.specifications = phone_data[:specifications]
  end
end

# Create Admin User
admin_user = User.find_or_create_by!(email: 'admin@store.com') do |user|
  user.name = 'Admin User'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.role = 'admin'
end

# Create Sample Customer
customer_user = User.find_or_create_by!(email: 'customer@store.com') do |user|
  user.name = 'John Doe'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.role = 'customer'
end

puts "Seeded #{Brand.count} brands, #{Category.count} categories, #{Phone.count} phones, and #{User.count} users"
