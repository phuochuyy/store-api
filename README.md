# Store API

A simple e-commerce RESTful API built with Ruby on Rails 8.

## Quick Start

1. **Start the application**
   ```bash
   docker compose up -d
   ```

2. **Setup database**
   ```bash
   docker compose exec web bundle exec rails db:create db:migrate db:seed
   ```

3. **Access the API**
   - API: http://localhost:3002
   - Health Check: http://localhost:3002/api/v1/health
   - Documentation: http://localhost:3002/api-docs

## Authentication

JWT-based authentication with token blacklisting:

```bash
# Login
curl -X POST http://localhost:3002/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}'

# Use token
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3002/api/v1/products
```

## API Endpoints

- **Products**: `/api/v1/products` - CRUD operations
- **Search**: `/api/v1/products/search?search=iPhone` - Product search
- **Brands**: `/api/v1/brands` - Brand management
- **Categories**: `/api/v1/categories` - Category management
- **Cart**: `/api/v1/carts` - Shopping cart
- **Orders**: `/api/v1/orders` - Order management

## Features

- JWT Authentication with token blacklisting
- Role-based authorization (Admin/Customer)
- Product search and filtering
- Shopping cart functionality
- Order management
- Swagger/OpenAPI documentation
- Docker containerization
- PostgreSQL database

## Technologies

- Ruby on Rails 8
- PostgreSQL
- JWT Authentication
- Docker & Docker Compose
- Swagger/OpenAPI
- RuboCop (code quality)

## Development

```bash
# Code quality check
docker compose exec web bundle exec rubocop

# Access Rails console
docker compose exec web bundle exec rails console

# View logs
docker compose logs web
```

## Default Users

- **Admin**: admin@example.com / password
- **Customer**: customer@example.com / password