# Phone Store API Documentation

## Base URL
```
http://localhost:3000/api/v1
```

## Authentication
All API endpoints (except login/register) require JWT authentication via Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

## Endpoints

### Authentication

#### Login
```http
POST /auth/login
Content-Type: application/json

{
  "email": "admin@example.com",
  "password": "password"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@example.com",
    "role": "admin"
  }
}
```

#### Register
```http
POST /auth/register
Content-Type: application/json

{
  "user": {
    "name": "New User",
    "email": "newuser@example.com",
    "password": "password",
    "password_confirmation": "password",
    "role": "customer"
  }
}
```

#### Get Current User
```http
GET /auth/me
Authorization: Bearer <token>
```

### Phones

#### Get All Phones
```http
GET /phones?page=1&per_page=10&brand_id=1&category_id=1&search=iPhone&min_price=500&max_price=1000
```

**Query Parameters:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 10)
- `brand_id` - Filter by brand ID
- `category_id` - Filter by category ID
- `search` - Search by name
- `min_price` - Minimum price
- `max_price` - Maximum price

**Response:**
```json
{
  "phones": [
    {
      "id": 1,
      "name": "iPhone 15 Pro",
      "description": "The most advanced iPhone...",
      "price": 999.99,
      "stock_quantity": 50,
      "in_stock": true,
      "brand": {
        "id": 1,
        "name": "Apple"
      },
      "category": {
        "id": 1,
        "name": "Flagship"
      },
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 50,
    "per_page": 10
  }
}
```

#### Get Phone by ID
```http
GET /phones/1
```

#### Create Phone (Admin Only)
```http
POST /phones
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "phone": {
    "name": "New Phone",
    "description": "A new phone description",
    "price": 299.99,
    "stock_quantity": 10,
    "brand_id": 1,
    "category_id": 1
  }
}
```

#### Update Phone (Admin Only)
```http
PUT /phones/1
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "phone": {
    "name": "Updated Phone Name",
    "price": 399.99
  }
}
```

#### Delete Phone (Admin Only)
```http
DELETE /phones/1
Authorization: Bearer <admin_token>
```

### Brands

#### Get All Brands
```http
GET /brands?page=1&per_page=10
```

#### Get Brand by ID
```http
GET /brands/1
```

#### Create Brand (Admin Only)
```http
POST /brands
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "brand": {
    "name": "New Brand",
    "description": "A new brand description"
  }
}
```

### Categories

#### Get All Categories
```http
GET /categories?page=1&per_page=10
```

#### Get Category by ID
```http
GET /categories/1
```

#### Create Category (Admin Only)
```http
POST /categories
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "category": {
    "name": "New Category",
    "description": "A new category description"
  }
}
```

### Orders

#### Get All Orders (Admin Only)
```http
GET /orders?page=1&per_page=10
Authorization: Bearer <admin_token>
```

#### Get Order by ID
```http
GET /orders/1
```

#### Create Order
```http
POST /orders
Content-Type: application/json

{
  "order": {
    "customer_name": "John Doe",
    "customer_email": "john@example.com",
    "customer_phone": "555-1234"
  },
  "order_items": [
    {
      "phone_id": 1,
      "quantity": 2
    },
    {
      "phone_id": 2,
      "quantity": 1
    }
  ]
}
```

#### Update Order (Admin Only)
```http
PUT /orders/1
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "order": {
    "status": "shipped"
  }
}
```

## Error Responses

### 400 Bad Request
```json
{
  "error": "Missing parameter",
  "message": "param is missing or the value is empty: phone",
  "status": 400
}
```

### 401 Unauthorized
```json
{
  "error": "Token missing"
}
```

### 403 Forbidden
```json
{
  "error": "Admin access required"
}
```

### 404 Not Found
```json
{
  "error": "Record not found",
  "message": "Couldn't find Phone with 'id'=999",
  "status": 404
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Validation failed",
  "message": "Phone could not be created",
  "errors": [
    "Name can't be blank",
    "Price must be greater than 0"
  ],
  "status": 422
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error",
  "message": "Something went wrong",
  "status": 500
}
```

## Status Codes

- `200` - OK
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Unprocessable Entity
- `500` - Internal Server Error

## Demo Accounts

- **Admin**: admin@example.com / password
- **Customer**: customer@example.com / password
