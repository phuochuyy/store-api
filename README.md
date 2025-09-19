# Phone Store API

RESTful API for a phone store built with Ruby on Rails.

## Features

- JWT Authentication
- Product Management (Brands, Categories, Phones)
- Order Management
- Image Upload
- Search & Filter
- Pagination
- Admin Statistics

## Setup

1. **Install dependencies**:
```bash
bundle install
```

2. **Start services**:
```bash
sudo docker compose up -d
```

3. **Setup database**:
```bash
rails db:create db:migrate db:seed
```

4. **Start server**:
```bash
rails server
```

API runs at `http://localhost:3000`

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/register` - Register

### Products
- `GET /api/v1/brands` - List brands
- `GET /api/v1/categories` - List categories
- `GET /api/v1/phones` - List phones
- `GET /api/v1/phones/:id` - Get phone details

### Orders
- `GET /api/v1/orders` - List orders
- `POST /api/v1/orders` - Create order
- `POST /api/v1/orders/:id/order_items` - Add item to order

### Admin (requires authentication)
- `POST /api/v1/brands` - Create brand
- `POST /api/v1/categories` - Create category
- `POST /api/v1/phones` - Create phone
- `GET /api/v1/statistics/dashboard` - Dashboard stats

## Query Parameters

**Phones:**
- `page`, `per_page` - Pagination
- `brand_id`, `category_id` - Filter
- `search` - Search by name

**Orders:**
- `page`, `per_page` - Pagination
- `status` - Filter by status

## Usage

### Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@store.com", "password": "password123"}'
```

### Get phones
```bash
curl "http://localhost:3000/api/v1/phones?page=1&per_page=10"
```

### Create order
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"order": {"customer_name": "John", "customer_email": "john@example.com", "total_amount": 999.99}}'
```

## Development

```bash
rails test          # Run tests
rails cache:clear   # Clear cache
```

## API Docs

Swagger UI: `http://localhost:3000/api-docs`