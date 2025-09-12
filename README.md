# Phone Store API

API RESTful cho cửa hàng điện thoại được xây dựng bằng Ruby on Rails.

## Tính năng

### Core Features
- **Quản lý thương hiệu (Brands)**: CRUD operations cho các thương hiệu điện thoại
- **Quản lý danh mục (Categories)**: CRUD operations cho các danh mục sản phẩm
- **Quản lý điện thoại (Phones)**: CRUD operations với tìm kiếm và phân trang
- **Quản lý đơn hàng (Orders)**: CRUD operations cho đơn hàng
- **Quản lý chi tiết đơn hàng (Order Items)**: CRUD operations cho items trong đơn hàng

### Advanced Features
- **Authentication & Authorization**: JWT-based authentication với role-based access control
- **Image Upload**: Upload hình ảnh cho điện thoại với Active Storage
- **Rate Limiting**: Bảo vệ API khỏi abuse và DDoS attacks
- **Redis Caching**: Caching thông minh để cải thiện hiệu suất
- **Phân trang**: Hỗ trợ phân trang cho tất cả endpoints với Kaminari
- **Tìm kiếm**: Tìm kiếm điện thoại theo tên
- **Lọc**: Lọc theo thương hiệu, danh mục, trạng thái đơn hàng
- **Thống kê & Báo cáo**: Dashboard, inventory, và sales statistics
- **API Documentation**: Swagger UI documentation
- **CORS Support**: Cross-origin resource sharing
- **Error Handling**: Comprehensive error handling và validation

## Cài đặt

### Yêu cầu hệ thống

- Ruby 3.0+
- Rails 8.0+
- MySQL 8.0+
- Redis 7.0+
- Docker & Docker Compose

### Cài đặt

1. Clone repository:
```bash
git clone <repository-url>
cd store-api
```

2. Cài đặt dependencies:
```bash
bundle install
```

3. Khởi động MySQL và Redis với Docker:
```bash
sudo docker compose up -d
```

4. Tạo và migrate database:
```bash
rails db:create
rails db:migrate
```

5. Tạo dữ liệu mẫu:
```bash
rails db:seed
```

6. Warm up cache (tùy chọn):
```bash
rails cache:warm
```

7. Khởi động server:
```bash
rails server
```

API sẽ chạy tại `http://localhost:3000`

## API Endpoints

### Authentication (Xác thực)

- `POST /api/v1/auth/login` - Đăng nhập
- `POST /api/v1/auth/register` - Đăng ký tài khoản
- `GET /api/v1/auth/me` - Lấy thông tin user hiện tại

### Brands (Thương hiệu)

- `GET /api/v1/brands` - Lấy danh sách tất cả thương hiệu
- `GET /api/v1/brands/:id` - Lấy thông tin thương hiệu theo ID
- `POST /api/v1/brands` - Tạo thương hiệu mới
- `PUT/PATCH /api/v1/brands/:id` - Cập nhật thương hiệu
- `DELETE /api/v1/brands/:id` - Xóa thương hiệu

### Categories (Danh mục)

- `GET /api/v1/categories` - Lấy danh sách tất cả danh mục
- `GET /api/v1/categories/:id` - Lấy thông tin danh mục theo ID
- `POST /api/v1/categories` - Tạo danh mục mới
- `PUT/PATCH /api/v1/categories/:id` - Cập nhật danh mục
- `DELETE /api/v1/categories/:id` - Xóa danh mục

### Phones (Điện thoại)

- `GET /api/v1/phones` - Lấy danh sách điện thoại (có phân trang)
- `GET /api/v1/phones/:id` - Lấy thông tin điện thoại theo ID
- `POST /api/v1/phones` - Tạo điện thoại mới
- `PUT/PATCH /api/v1/phones/:id` - Cập nhật điện thoại
- `DELETE /api/v1/phones/:id` - Xóa điện thoại
- `POST /api/v1/phones/:id/upload_image` - Upload hình ảnh cho điện thoại
- `DELETE /api/v1/phones/:id/remove_image` - Xóa hình ảnh của điện thoại

#### Query Parameters cho Phones

- `page` - Trang hiện tại (mặc định: 1)
- `per_page` - Số item mỗi trang (mặc định: 10)
- `brand_id` - Lọc theo thương hiệu
- `category_id` - Lọc theo danh mục
- `search` - Tìm kiếm theo tên

### Orders (Đơn hàng)

- `GET /api/v1/orders` - Lấy danh sách đơn hàng (có phân trang)
- `GET /api/v1/orders/:id` - Lấy thông tin đơn hàng theo ID
- `POST /api/v1/orders` - Tạo đơn hàng mới
- `PUT/PATCH /api/v1/orders/:id` - Cập nhật đơn hàng
- `DELETE /api/v1/orders/:id` - Xóa đơn hàng

#### Query Parameters cho Orders

- `page` - Trang hiện tại (mặc định: 1)
- `per_page` - Số item mỗi trang (mặc định: 10)
- `status` - Lọc theo trạng thái (pending, confirmed, shipped, delivered, cancelled)
- `customer_email` - Tìm kiếm theo email khách hàng

### Order Items (Chi tiết đơn hàng)

- `GET /api/v1/orders/:order_id/order_items` - Lấy danh sách items của đơn hàng
- `GET /api/v1/order_items/:id` - Lấy thông tin order item theo ID
- `POST /api/v1/orders/:order_id/order_items` - Thêm item vào đơn hàng
- `PUT/PATCH /api/v1/order_items/:id` - Cập nhật order item
- `DELETE /api/v1/order_items/:id` - Xóa order item

### Statistics (Thống kê) - Admin Only

- `GET /api/v1/statistics/dashboard` - Dashboard tổng quan
- `GET /api/v1/statistics/inventory` - Thống kê kho hàng
- `GET /api/v1/statistics/sales` - Thống kê bán hàng

#### Query Parameters cho Statistics

- `start_date` - Ngày bắt đầu (format: YYYY-MM-DD)
- `end_date` - Ngày kết thúc (format: YYYY-MM-DD)

## Ví dụ sử dụng

### Authentication

#### Đăng nhập
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@store.com",
    "password": "password123"
  }'
```

#### Đăng ký tài khoản mới
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": "John Doe",
      "email": "john@example.com",
      "password": "password123",
      "password_confirmation": "password123",
      "role": "customer"
    }
  }'
```

### Tạo thương hiệu mới (Admin only)

```bash
curl -X POST http://localhost:3000/api/v1/brands \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "brand": {
      "name": "Huawei",
      "description": "Chinese smartphone manufacturer"
    }
  }'
```

### Lấy danh sách điện thoại với phân trang

```bash
curl "http://localhost:3000/api/v1/phones?page=1&per_page=5"
```

### Tìm kiếm điện thoại

```bash
curl "http://localhost:3000/api/v1/phones?search=iPhone"
```

### Lọc điện thoại theo thương hiệu

```bash
curl "http://localhost:3000/api/v1/phones?brand_id=1"
```

### Tạo điện thoại mới với hình ảnh

```bash
curl -X POST http://localhost:3000/api/v1/phones \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "phone[name]=iPhone 15 Pro" \
  -F "phone[description]=Latest iPhone with advanced features" \
  -F "phone[price]=999.99" \
  -F "phone[brand_id]=1" \
  -F "phone[category_id]=1" \
  -F "phone[stock_quantity]=50" \
  -F "phone[specifications]=A17 Pro chip, 6.1-inch display" \
  -F "phone[image]=@/path/to/image.jpg"
```

### Upload hình ảnh cho điện thoại

```bash
curl -X POST http://localhost:3000/api/v1/phones/1/upload_image \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "image=@/path/to/new-image.jpg"
```

### Xóa hình ảnh của điện thoại

```bash
curl -X DELETE http://localhost:3000/api/v1/phones/1/remove_image \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Tạo đơn hàng mới

```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "order": {
      "customer_name": "Nguyễn Văn A",
      "customer_email": "nguyenvana@example.com",
      "customer_phone": "0123456789",
      "total_amount": 999.99,
      "status": "pending"
    }
  }'
```

### Thêm item vào đơn hàng

```bash
curl -X POST http://localhost:3000/api/v1/orders/1/order_items \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "order_item": {
      "phone_id": 1,
      "quantity": 2
    }
  }'
```

### Xem thống kê dashboard (Admin only)

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/v1/statistics/dashboard
```

## Image Upload Features

### Hỗ trợ định dạng
- JPEG/JPG
- PNG
- GIF
- WebP

### Giới hạn
- Kích thước tối đa: 5MB
- Mỗi điện thoại có thể có 1 hình ảnh

### Validation
- Kiểm tra định dạng file
- Kiểm tra kích thước file
- Hỗ trợ cả upload file và URL hình ảnh

## Rate Limiting

API được bảo vệ bởi rate limiting để ngăn chặn abuse:

### Rate Limits
- **API chung**: 100 requests/phút per IP
- **Authentication**: 10 requests/phút per IP  
- **Image uploads**: 20 requests/phút per IP
- **Authenticated users**: 200 requests/phút
- **Admin users**: 50 requests/phút

### Response Headers
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

### Rate Limit Exceeded (429)
```json
{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Please try again later.",
  "retry_after": 60
}
```

## Caching

API sử dụng Redis caching để cải thiện hiệu suất:

### Cache Management
```bash
# Warm up all caches
rails cache:warm

# Clear all caches  
rails cache:clear

# Show cache statistics
rails cache:stats

# Invalidate specific cache
rails cache:invalidate[phones]
```

### Cache TTL
- **Phones**: 1 hour
- **Brands/Categories**: 1 day
- **Statistics**: 15 minutes
- **User data**: 1 hour

## API Documentation

Swagger UI documentation có sẵn tại: `http://localhost:3000/api-docs`

## Cấu trúc Database

### Brands
- `id` - Primary key
- `name` - Tên thương hiệu (unique)
- `description` - Mô tả thương hiệu
- `created_at`, `updated_at` - Timestamps

### Categories
- `id` - Primary key
- `name` - Tên danh mục (unique)
- `description` - Mô tả danh mục
- `created_at`, `updated_at` - Timestamps

### Phones
- `id` - Primary key
- `name` - Tên điện thoại
- `description` - Mô tả sản phẩm
- `price` - Giá (decimal, precision: 10, scale: 2)
- `brand_id` - Foreign key đến Brands
- `category_id` - Foreign key đến Categories
- `stock_quantity` - Số lượng tồn kho
- `image_url` - URL hình ảnh (fallback)
- `specifications` - Thông số kỹ thuật
- `created_at`, `updated_at` - Timestamps

### Orders
- `id` - Primary key
- `customer_name` - Tên khách hàng
- `customer_email` - Email khách hàng
- `customer_phone` - Số điện thoại khách hàng
- `total_amount` - Tổng tiền (decimal, precision: 10, scale: 2)
- `status` - Trạng thái đơn hàng (enum)
- `created_at`, `updated_at` - Timestamps

### Order Items
- `id` - Primary key
- `order_id` - Foreign key đến Orders
- `phone_id` - Foreign key đến Phones
- `quantity` - Số lượng
- `unit_price` - Giá đơn vị (decimal, precision: 10, scale: 2)
- `created_at`, `updated_at` - Timestamps

### Active Storage Tables
- `active_storage_blobs` - Thông tin file đã upload
- `active_storage_attachments` - Liên kết file với model
- `active_storage_variant_records` - Variants của hình ảnh

## Testing

Chạy tests:

```bash
rails test
```

## Docker

Khởi động services:

```bash
sudo docker compose up -d
```

Dừng services:

```bash
sudo docker compose down
```

## License

MIT License