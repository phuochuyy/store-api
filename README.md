# Phone Store API

RESTful API for a phone store built with Ruby on Rails.

## Features

- JWT Authentication with role-based access control
- Product Management (Brands, Categories, Phones)
- Order Management with nested order items
- Image Upload for phones using Active Storage
- Search & Filter capabilities
- Pagination support
- Admin Statistics Dashboard
- Comprehensive error handling

## Tech Stack

- **Backend**: Ruby 3.3.9, Rails 8.0.2
- **Database**: MySQL 8.0
- **Cache**: Redis 7.0
- **Authentication**: JWT tokens
- **File Storage**: Active Storage
- **Testing**: RSpec
- **Containerization**: Docker

## Quick Start

### Prerequisites

- Ruby 3.3.9+
- Rails 8.0+
- MySQL 8.0+
- Redis 7.0+
- Docker & Docker Compose

### Installation

1. **Clone and setup**:

```bash
git clone <repository-url>
cd store-api
cp .env.example .env
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
- `GET /api/v1/auth/me` - Get current user

### Products

- `GET /api/v1/brands` - List brands
- `GET /api/v1/categories` - List categories
- `GET /api/v1/phones` - List phones (with search, filter, pagination)
- `GET /api/v1/phones/:id` - Get phone details
- `POST /api/v1/phones/:id/upload_image` - Upload phone image (Admin)
- `DELETE /api/v1/phones/:id/remove_image` - Remove phone image (Admin)

### Orders

- `GET /api/v1/orders` - List orders
- `POST /api/v1/orders` - Create order
- `POST /api/v1/orders/:id/order_items` - Add item to order
- `GET /api/v1/orders/:id/order_items` - List order items

### Admin Only

- `POST /api/v1/brands` - Create brand
- `POST /api/v1/categories` - Create category
- `POST /api/v1/phones` - Create phone
- `GET /api/v1/statistics/dashboard` - Dashboard stats

## Query Parameters

**Phones:**

- `page`, `per_page` - Pagination
- `brand_id`, `category_id` - Filter
- `search` - Search by name
- `min_price`, `max_price` - Price range

**Orders:**

- `page`, `per_page` - Pagination
- `status` - Filter by status (pending, confirmed, shipped, delivered, cancelled)

## Authentication

All endpoints (except login/register) require JWT token in Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

## API Documentation

- **Swagger UI**: `http://localhost:3000/api-docs`
- **API Spec**: `http://localhost:3000/api-docs/v1/swagger.yaml`

## Development

### Testing

```bash
bundle exec rspec          # Run tests
bundle exec rubocop        # Code style check
bundle exec brakeman       # Security scan
```

### CI/CD

- Automated testing on push/PR
- Security scanning with Brakeman
- Docker build and test
- Code quality checks

## Environment Variables

Copy `.env.example` to `.env` and configure:

- Database credentials
- JWT secret keys
- Redis URL
- File upload settings

## License

MIT License
