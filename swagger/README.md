# Store API Documentation

## Cấu trúc Swagger Modular

API documentation đã được tái cấu trúc thành dạng modular để dễ quản lý và bảo trì.

### Cấu trúc thư mục

```
swagger/
├── v1/
│   ├── swagger.yaml              # File chính chứa thông tin cơ bản và references
│   ├── components/
│   │   ├── schemas.yaml          # Định nghĩa các data models
│   │   └── responses.yaml        # Định nghĩa các response templates
│   └── paths/
│       ├── auth.yaml             # Authentication endpoints
│       ├── health.yaml           # Health check endpoints
│       ├── products.yaml         # Product management endpoints
│       ├── brands.yaml           # Brand management endpoints
│       ├── categories.yaml       # Category management endpoints
│       ├── carts.yaml            # Shopping cart endpoints
│       ├── orders.yaml           # Order management endpoints
│       ├── discounts.yaml        # Discount management endpoints
│       ├── promotions.yaml       # Promotion management endpoints
│       ├── payment_methods.yaml  # Payment method endpoints
│       ├── payments.yaml         # Payment processing endpoints
│       ├── notifications.yaml    # Notification endpoints
│       ├── stock_alerts.yaml     # Stock alert endpoints
│       └── statistics.yaml       # Statistics endpoints
└── README.md                     # File này
```

### Các thay đổi chính

#### 1. Loại bỏ các endpoint không sử dụng:
- Password Reset (không có routes thực tế)
- Product Reviews (không có routes thực tế)
- Product Wishlists (không có routes thực tế)
- Product Comparisons (không có routes thực tế)
- Product Recommendations (không có routes thực tế)
- Stock Movements (không có routes thực tế)
- Payment Histories (không có routes thực tế)
- User Profile/Addresses (không có routes thực tế)

#### 2. Thêm các endpoint thực tế:
- **Payment Methods**: Quản lý phương thức thanh toán
- **Payments**: Xử lý thanh toán
- **Discounts**: Quản lý mã giảm giá
- **Promotions**: Quản lý chương trình khuyến mãi
- **Notifications**: Quản lý thông báo
- **Stock Alerts**: Quản lý cảnh báo tồn kho
- **Statistics**: Thống kê và báo cáo

#### 3. Cập nhật routes.rb:
Đã thêm các routes thiếu:
```ruby
# Payment Methods
resources :payment_methods do
  member do
    get :stats
    post :validate_config
  end
  collection do
    post :calculate_fees
  end
end

# Payments
resources :payments do
  member do
    post :refund
  end
end

# Statistics
namespace :statistics do
  get :dashboard
  get :inventory
  get :sales
end
```

### Lợi ích của cấu trúc modular

1. **Dễ bảo trì**: Mỗi file chứa endpoints của một domain cụ thể
2. **Dễ mở rộng**: Thêm endpoint mới chỉ cần sửa file tương ứng
3. **Tái sử dụng**: Schemas và responses được định nghĩa chung
4. **Dễ đọc**: File chính ngắn gọn, dễ hiểu cấu trúc tổng thể
5. **Team collaboration**: Nhiều người có thể làm việc trên các file khác nhau

### Cách sử dụng

1. **Xem documentation**: Truy cập `/api-docs` để xem Swagger UI
2. **Chỉnh sửa**: Sửa file tương ứng trong thư mục `paths/` hoặc `components/`
3. **Thêm endpoint mới**: Tạo file mới trong `paths/` và reference trong `swagger.yaml`
4. **Thêm schema mới**: Thêm vào `components/schemas.yaml`

### Các endpoint chính

#### Authentication
- `POST /api/v1/auth/login` - Đăng nhập
- `POST /api/v1/auth/register` - Đăng ký
- `GET /api/v1/auth/me` - Thông tin user hiện tại
- `POST /api/v1/auth/logout` - Đăng xuất

#### Products
- `GET /api/v1/products` - Danh sách sản phẩm
- `POST /api/v1/products` - Tạo sản phẩm mới
- `GET /api/v1/products/{id}` - Chi tiết sản phẩm
- `PUT /api/v1/products/{id}` - Cập nhật sản phẩm
- `DELETE /api/v1/products/{id}` - Xóa sản phẩm

#### Orders
- `GET /api/v1/orders` - Danh sách đơn hàng
- `POST /api/v1/orders` - Tạo đơn hàng mới
- `POST /api/v1/orders/{id}/confirm` - Xác nhận đơn hàng
- `POST /api/v1/orders/{id}/cancel` - Hủy đơn hàng

#### Payments
- `POST /api/v1/payments` - Xử lý thanh toán
- `POST /api/v1/payments/{id}/refund` - Hoàn tiền
- `GET /api/v1/payment_methods` - Danh sách phương thức thanh toán

#### Statistics (Admin only)
- `GET /api/v1/statistics/dashboard` - Thống kê tổng quan
- `GET /api/v1/statistics/inventory` - Thống kê tồn kho
- `GET /api/v1/statistics/sales` - Thống kê bán hàng

### Lưu ý

- Tất cả endpoints yêu cầu authentication trừ login, register, health check
- Một số endpoints yêu cầu quyền admin
- API sử dụng JWT token cho authentication
- Tất cả responses đều có format chuẩn với `success`, `data`, `message`
