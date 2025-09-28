# 📚 Swagger API Documentation Guide

## 🎯 Tổng quan

Dự án Store API đã được cập nhật với Swagger documentation hoàn chỉnh và chuyên nghiệp. Tài liệu này cung cấp hướng dẫn chi tiết về cách sử dụng và tùy chỉnh Swagger documentation.

## 🚀 Truy cập Swagger UI

### Development Environment
```
http://localhost:3000/api-docs
```

### Production Environment
```
https://api.store.com/api-docs
```

## 📋 Tính năng Swagger đã implement

### ✅ **1. API Information**
- **Title**: Store API V1
- **Version**: v1
- **Description**: Comprehensive e-commerce API documentation
- **Contact**: Store API Support (support@store-api.com)
- **License**: MIT

### ✅ **2. Server Configuration**
- Development server: `http://localhost:3000`
- Production server: `https://api.store.com`

### ✅ **3. Authentication**
- **JWT Bearer Token** authentication
- Security scheme được định nghĩa rõ ràng
- Hướng dẫn sử dụng token trong header

### ✅ **4. API Endpoints Documentation**

#### **Authentication Endpoints**
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration
- `GET /api/v1/auth/verify_email` - Email verification
- `POST /api/v1/auth/resend_verification` - Resend verification email
- `GET /api/v1/auth/me` - Get current user
- `POST /api/v1/auth/logout` - User logout
- `POST /api/v1/auth/refresh_token` - Refresh access token

#### **Shopping Cart Endpoints**
- `GET /api/v1/carts` - Get user's cart
- `POST /api/v1/carts` - Create new cart
- `GET /api/v1/carts/{id}` - Get cart details
- `PUT /api/v1/carts/{id}` - Update cart
- `DELETE /api/v1/carts/{id}` - Delete cart
- `DELETE /api/v1/carts/{id}/clear` - Clear cart
- `POST /api/v1/carts/merge` - Merge carts

#### **Cart Items Endpoints**
- `GET /api/v1/carts/{cart_id}/cart_items` - Get cart items
- `POST /api/v1/carts/{cart_id}/cart_items` - Add item to cart
- `GET /api/v1/carts/{cart_id}/cart_items/{id}` - Get cart item
- `PUT /api/v1/carts/{cart_id}/cart_items/{id}` - Update cart item
- `DELETE /api/v1/carts/{cart_id}/cart_items/{id}` - Remove cart item

#### **Health Check**
- `GET /api/v1/health` - System health check

### ✅ **5. Data Schemas**

#### **Core Schemas**
- **User**: User information with email verification
- **Product**: Product catalog with brand and category
- **Brand**: Brand information
- **Category**: Category information
- **Cart**: Shopping cart with status management
- **CartItem**: Cart item with product details
- **Order**: Order information
- **OrderItem**: Order item details

#### **Response Schemas**
- **SuccessResponse**: Standard success response format
- **ErrorResponse**: Standard error response format

### ✅ **6. Error Handling**
- **400 Bad Request**: Invalid parameters
- **401 Unauthorized**: Authentication required
- **404 Not Found**: Resource not found
- **422 Validation Error**: Invalid input data
- **500 Internal Server Error**: Server error

### ✅ **7. Tags và Organization**
- **Authentication**: User authentication and email verification
- **Users**: User management
- **Products**: Product catalog management
- **Brands**: Brand management
- **Categories**: Category management
- **Shopping Cart**: Shopping cart operations
- **Orders**: Order management
- **Health**: System health checks

## 🔧 Cấu trúc file Swagger

### File chính: `swagger/v1/swagger.yaml`

```yaml
openapi: 3.0.1
info:
  title: Store API V1
  version: v1
  description: |
    RESTful API for an e-commerce store built with Ruby on Rails.
    # ... detailed description
```

### Các thành phần chính:

1. **Info Section**: Thông tin API, contact, license
2. **Servers**: Development và production servers
3. **Tags**: Organization của endpoints
4. **Paths**: Tất cả API endpoints với chi tiết
5. **Components**: Schemas, security schemes, responses
6. **Security**: JWT authentication configuration

## 📝 Cách sử dụng Swagger UI

### 1. **Authentication**
1. Mở Swagger UI
2. Click vào "Authorize" button
3. Nhập JWT token: `Bearer <your-token>`
4. Click "Authorize"

### 2. **Testing Endpoints**
1. Chọn endpoint muốn test
2. Click "Try it out"
3. Nhập parameters/request body
4. Click "Execute"
5. Xem response

### 3. **Schema Reference**
- Xem tất cả data models trong "Schemas" section
- Hiểu cấu trúc request/response data
- Copy examples để sử dụng

## 🛠️ Tùy chỉnh và mở rộng

### Thêm endpoint mới:

1. **Thêm path vào `paths` section:**
```yaml
/api/v1/new-endpoint:
  get:
    tags:
      - New Tag
    summary: New endpoint
    description: Description of new endpoint
    responses:
      '200':
        description: Success response
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/success_response'
```

2. **Thêm schema mới vào `components/schemas`:**
```yaml
new_model:
  type: object
  properties:
    id:
      type: integer
      example: 1
    name:
      type: string
      example: "Example"
```

3. **Thêm tag mới vào `tags` section:**
```yaml
- name: New Tag
  description: Description of new tag
```

### Cập nhật existing endpoints:

1. **Thêm parameters:**
```yaml
parameters:
  - name: new_param
    in: query
    required: true
    schema:
      type: string
    description: New parameter description
```

2. **Thêm response codes:**
```yaml
responses:
  '201':
    description: Created successfully
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/success_response'
```

## 🎨 Best Practices

### 1. **Consistent Naming**
- Sử dụng snake_case cho field names
- Sử dụng descriptive names
- Consistent với Rails conventions

### 2. **Detailed Descriptions**
- Mô tả rõ ràng cho mỗi endpoint
- Giải thích parameters và responses
- Thêm examples thực tế

### 3. **Error Handling**
- Định nghĩa tất cả possible error responses
- Sử dụng standard HTTP status codes
- Consistent error message format

### 4. **Security**
- Document authentication requirements
- Sử dụng security schemes
- Mark sensitive endpoints

## 🔍 Validation và Testing

### 1. **YAML Validation**
```bash
# Validate YAML syntax
yamllint swagger/v1/swagger.yaml

# Validate OpenAPI spec
swagger-codegen validate -i swagger/v1/swagger.yaml
```

### 2. **Testing với Swagger UI**
- Test tất cả endpoints
- Verify request/response formats
- Check error handling

### 3. **Integration Testing**
- Test với real API
- Verify authentication flow
- Test edge cases

## 📚 Resources

### Documentation Links:
- [OpenAPI Specification](https://swagger.io/specification/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [Rails API Documentation](https://guides.rubyonrails.org/api_app.html)

### Tools:
- [Swagger Editor](https://editor.swagger.io/)
- [Postman](https://www.postman.com/) - Import từ Swagger
- [Insomnia](https://insomnia.rest/) - API testing

## 🚀 Deployment

### Development:
```bash
# Start Rails server
docker compose up

# Access Swagger UI
open http://localhost:3000/api-docs
```

### Production:
1. Deploy Rails application
2. Ensure `/api-docs` route is accessible
3. Update server URLs in swagger.yaml
4. Test all endpoints

## 🎉 Kết quả

Swagger documentation hiện tại cung cấp:

✅ **Complete API Coverage** - Tất cả endpoints được document
✅ **Professional Presentation** - UI đẹp và dễ sử dụng
✅ **Detailed Schemas** - Data models được định nghĩa rõ ràng
✅ **Authentication Guide** - Hướng dẫn sử dụng JWT
✅ **Error Handling** - Tất cả error cases được cover
✅ **Examples** - Real-world examples cho mọi endpoint
✅ **Interactive Testing** - Test API trực tiếp từ UI
✅ **Developer Friendly** - Dễ hiểu và sử dụng

Swagger documentation giờ đây là một tài liệu hoàn chỉnh và chuyên nghiệp cho Store API, giúp developers dễ dàng hiểu và sử dụng API!
