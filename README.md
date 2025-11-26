# Store API

A simple e-commerce RESTful API built with Ruby on Rails 8.

## Quick Start

### Development Setup

Development environment runs Rails server locally with Docker containers for DB and Redis.

1. **Start database and Redis containers**
   ```bash
   docker compose up -d
   # or use Makefile
   make docker-dev-up
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   bundle exec rails db:create db:migrate db:seed
   ```

4. **Start Rails server**
   ```bash
   bundle exec rails server
   # or
   bin/dev
   ```

5. **Access the API**
   - API: http://localhost:3000
   - Health Check: http://localhost:3000/api/v1/health
   - Documentation: http://localhost:3000/api-docs

### Production Setup

For production deployment with full Docker stack:

1. **Set environment variables**
   ```bash
   export DATABASE_PASSWORD=your_secure_password
   export REDIS_PASSWORD=your_redis_password
   export SECRET_KEY_BASE=your_secret_key_base
   export RAILS_MASTER_KEY=your_master_key
   ```

2. **Start production containers**
   ```bash
   docker compose -f docker-compose.prod.yml up -d
   # or use Makefile
   make docker-prod-up
   ```

3. **Setup production database**
   ```bash
   docker compose -f docker-compose.prod.yml exec web bundle exec rails db:create db:migrate db:seed RAILS_ENV=production
   ```

### Docker Commands

See `Makefile.docker` for convenient commands:
- `make docker-dev-up` - Start development containers
- `make docker-dev-down` - Stop development containers
- `make docker-dev-logs` - View container logs
- `make docker-dev-shell-db` - Open PostgreSQL shell
- `make docker-dev-shell-redis` - Open Redis shell

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
bundle exec rubocop

# Access Rails console
bundle exec rails console

# Access database shell
make docker-dev-shell-db
# or
docker compose exec db psql -U store_api -d store_api_development

# Access Redis shell
make docker-dev-shell-redis
# or
docker compose exec redis redis-cli

# View container logs
make docker-dev-logs
# or
docker compose logs -f
```

## Testing

```bash
# Run all tests
make test
# or
docker compose exec web bundle exec rspec

# Run authentication tests only
make test-auth

# Run a specific test file
make test-single FILE=spec/services/auth/auth_service_spec.rb

# Setup test database
make db-test-setup

# Run tests with coverage
make test-coverage
```

### Test Environment Setup

Tests require:
- PostgreSQL (test database)
- Redis (for JWT caching tests)

Both services are available in Docker Compose. The test environment will:
- Use Redis for caching if available
- Fallback to memory store if Redis is not available
- Automatically clean up Redis cache between tests

## Default Users

- **Admin**: admin@example.com / password
- **Customer**: customer@example.com / password