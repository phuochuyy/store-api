# Phone Store API

A modern RESTful API for a phone store built with Ruby on Rails 8.

## Quick Start

### Prerequisites
- Ruby 3.3.9
- PostgreSQL 15
- Redis 7
- Docker & Docker Compose

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
   docker compose exec web rails db:create db:migrate db:seed
   ```

4. **Access the API**
   - API: http://localhost:3000
   - Health Check: http://localhost:3000/api/v1/health
   - Documentation: http://localhost:3000/api-docs (after generating docs)

## Authentication

The API uses JWT authentication. Get your token by logging in:

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}'
```

Use the token in subsequent requests:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/phones
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/register` - Register
- `POST /api/v1/auth/refresh_token` - Refresh token
- `GET /api/v1/auth/me` - Get current user

### Resources
- `GET /api/v1/phones` - List phones (with filters & pagination)
- `GET /api/v1/phones/:id` - Get phone details
- `POST /api/v1/phones` - Create phone (Admin only)
- `PUT /api/v1/phones/:id` - Update phone (Admin only)
- `DELETE /api/v1/phones/:id` - Delete phone (Admin only)

- `GET /api/v1/brands` - List brands
- `GET /api/v1/categories` - List categories
- `GET /api/v1/orders` - List orders

## Architecture

The API follows enterprise-grade architecture patterns:

```
app/
├── controllers/     # API endpoints
├── services/        # Business logic
├── serializers/     # Data formatting
├── validators/      # Input validation
├── policies/        # Authorization
└── models/          # Database models
```

## Development

### Code Quality
```bash
# Run RuboCop
bundle exec rubocop

# Security scan
bundle exec brakeman

# Run tests
bundle exec rspec
```

### Database
```bash
# Reset database
docker compose exec web rails db:reset

# Run migrations
docker compose exec web rails db:migrate
```

## Features

- **JWT Authentication** with role-based access
- **RESTful API** with consistent responses
- **Pagination & Filtering** for all resources
- **Image Upload** support via Active Storage
- **API Documentation** with Swagger UI
- **Security Scanning** with Brakeman
- **Code Quality** with RuboCop
- **Testing** with RSpec
- **Docker** containerization

## Security

- JWT token authentication
- Role-based authorization (Admin/Customer)
- Input validation and sanitization
- Security vulnerability scanning
- CORS configuration

## Response Format

All API responses follow this format:

**Success:**
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}
```

**Error:**
```json
{
  "success": false,
  "error": "Error message",
  "status": "error_code"
}
```

## Docker Commands

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f web

# Execute commands
docker compose exec web rails console
docker compose exec web bundle exec rspec

# Stop services
docker compose down
```

## Documentation

- **Health Check**: http://localhost:3000/api/v1/health
- **API Docs**: http://localhost:3000/api-docs (run `rails rswag:specs:swaggerize` to generate)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and quality checks
5. Submit a pull request
