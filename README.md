# Simple Store API

A clean and simple e-commerce RESTful API built with Ruby on Rails 8, perfect for learning and demonstrating basic CRUD operations, authentication, and API design patterns.

## 🎯 **Perfect for Intern/Fresher Position**

This project demonstrates:
- **Basic CRUD Operations** - Create, Read, Update, Delete
- **JWT Authentication** - Simple token-based auth
- **RESTful API Design** - Clean and consistent endpoints
- **Database Relationships** - Basic associations
- **Test Coverage** - Essential testing patterns
- **Docker Setup** - Containerized development

## 🚀 **Quick Start**

### Prerequisites
- Ruby 3.3.9
- PostgreSQL 15
- Docker & Docker Compose

### 🆕 **What's New - No Redis Required!**
This project has been updated to work without Redis, using PostgreSQL for JWT token blacklisting instead. This makes it simpler to deploy and maintain.

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd store-api
   ```

2. **Start with Docker**
   ```bash
   docker compose up -d
   ```

3. **Setup database**
   ```bash
   docker compose exec web bundle exec rails db:create db:migrate db:seed
   ```

4. **Access the API**
   - API: http://localhost:3000
   - Health Check: http://localhost:3000/api/v1/health
   - Swagger Documentation: http://localhost:3000/api-docs

## 🔐 **Authentication**

Simple JWT authentication with database-backed token blacklisting:

```bash
# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}'

# Use token in requests
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/products
```

## 🛠️ **JWT Token Management**

The project uses PostgreSQL for JWT token blacklisting instead of Redis. This provides better persistence and simpler deployment.

### Available Rake Tasks

```bash
# Clean up expired tokens
docker compose exec web bundle exec rails jwt:cleanup

# Show blacklist statistics
docker compose exec web bundle exec rails jwt:stats

# Test blacklist functionality
docker compose exec web bundle exec rails jwt:test

# Clear all tokens (use with caution)
docker compose exec web bundle exec rails jwt:clear_all
```

### Token Blacklisting Features

- **Automatic Cleanup**: Expired tokens are automatically excluded from blacklist checks
- **User Tracking**: Tokens are associated with user IDs for better management
- **Token Types**: Support for different token types (access, refresh, password_reset, email_verification)
- **Reason Tracking**: Log reasons for token blacklisting
- **Statistics**: Get detailed statistics about blacklisted tokens

## 📋 **Core Features**

### ✅ **User Management**
- User registration and login
- JWT token authentication
- Role-based access (Admin/Customer)

### ✅ **Product Management**
- Product CRUD operations
- Product search and filtering
- Image upload support
- Brand and Category management

### ✅ **Shopping Cart**
- Add/remove items from cart
- Update quantities
- Clear cart functionality

### ✅ **Order Management**
- Create orders from cart
- Order confirmation and cancellation
- Order status tracking

### ✅ **Basic Notifications**
- Simple notification system
- Mark notifications as read

### ✅ **Stock Management**
- Basic stock tracking
- Low stock alerts

## 🛠️ **API Endpoints**

### 🔐 **Authentication**
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/logout` - User logout
- `GET /api/v1/auth/me` - Get current user

### 🛍️ **Products**
- `GET /api/v1/products` - List products
- `GET /api/v1/products/:id` - Get product details
- `POST /api/v1/products` - Create product (Admin)
- `PATCH /api/v1/products/:id` - Update product (Admin)
- `DELETE /api/v1/products/:id` - Delete product (Admin)
- `GET /api/v1/products/search` - Search products

### 🏷️ **Brands & Categories**
- `GET /api/v1/brands` - List brands
- `POST /api/v1/brands` - Create brand (Admin)
- `GET /api/v1/categories` - List categories
- `POST /api/v1/categories` - Create category (Admin)

### 🛒 **Shopping Cart**
- `GET /api/v1/carts` - Get user's cart
- `POST /api/v1/carts` - Create new cart
- `DELETE /api/v1/carts/:id` - Delete cart
- `DELETE /api/v1/carts/:id/clear` - Clear cart

### 📦 **Orders**
- `GET /api/v1/orders` - List orders
- `POST /api/v1/orders` - Create order
- `GET /api/v1/orders/:id` - Get order details
- `POST /api/v1/orders/:id/confirm` - Confirm order (Admin)
- `POST /api/v1/orders/:id/cancel` - Cancel order

### 🔔 **Notifications**
- `GET /api/v1/notifications` - List notifications
- `PATCH /api/v1/notifications/:id` - Update notification
- `POST /api/v1/notifications/:id/mark_read` - Mark as read

### 🏥 **System**
- `GET /api/v1/health` - Health check

## 🏗️ **Architecture**

Simple and clean architecture:

```
app/
├── controllers/     # API endpoints
├── models/          # Database models
├── services/        # Business logic
├── serializers/     # JSON responses
├── validators/      # Input validation
└── policies/        # Authorization
```

## 🧪 **Testing**

Run tests with RSpec:

```bash
# Run all tests
docker compose exec web bundle exec rspec

# Run specific test
docker compose exec web bundle exec rspec spec/models/user_spec.rb

# Run with coverage
docker compose exec web COVERAGE=true bundle exec rspec
```

## 🛠️ **Development**

### Essential Commands
```bash
# Start development
docker compose up -d

# Rails console
docker compose exec web bundle exec rails console

# Run tests
docker compose exec web bundle exec rspec

# Database operations
docker compose exec web bundle exec rails db:migrate
docker compose exec web bundle exec rails db:seed
```

### Code Quality
```bash
# Code style check
docker compose exec web bundle exec rubocop

# Security scan
docker compose exec web bundle exec brakeman
```

## 📊 **Database Schema**

### Core Tables
- **users** - User accounts
- **products** - Product catalog
- **brands** - Product brands
- **categories** - Product categories
- **carts** - Shopping carts
- **cart_items** - Cart contents
- **orders** - Customer orders
- **order_items** - Order contents
- **notifications** - System notifications
- **stock_alerts** - Stock warnings

## 🎯 **Learning Objectives**

This project demonstrates:

1. **RESTful API Design** - Clean, consistent endpoints
2. **Authentication** - JWT token-based security
3. **Database Design** - Proper relationships and constraints
4. **Testing** - Unit and integration tests
5. **Docker** - Containerized development
6. **Code Organization** - Service layer pattern
7. **Error Handling** - Proper HTTP status codes
8. **Documentation** - Swagger API docs

## 🚀 **Getting Started Examples**

### 1. Create User Account
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123"
  }'
```

### 2. Login and Get Token
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

### 3. Browse Products
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/products
```

### 4. Add Product to Cart
```bash
curl -X POST http://localhost:3000/api/v1/carts/1/cart_items \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 1,
    "quantity": 2
  }'
```

### 5. Create Order
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "John Doe",
    "customer_email": "john@example.com",
    "customer_phone": "1234567890"
  }'
```

## 📚 **Documentation**

- **Health Check**: http://localhost:3000/api/v1/health
- **Swagger UI**: http://localhost:3000/api-docs
- **API JSON**: http://localhost:3000/swagger/v1/swagger.json

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run quality checks
6. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License.

---

**Built with ❤️ using Ruby on Rails 8 - Perfect for learning and demonstrating API development skills!**