# 02 · Bản đồ domain

> Cập nhật theo commit: `0cbef93`

Tài liệu này dùng khi bạn cần biết một tính năng nằm ở đâu, nó gọi sang domain nào, và nếu tách thành microservice thì đường ranh giới nằm ở đâu.

## Các domain

| Domain | Models chính | Services | Ghi chú |
|---|---|---|---|
| **Auth** | `User`, `JwtBlacklistToken`, `PasswordResetToken` | `auth/auth_service`, `auth/token_validation_service`, `auth/jwt/*` | Xem [01 · Xác thực](01-architecture.md#xác-thực-jwt) |
| **Catalog** | `Product`, `ProductVariant`, `VariantOption`, `Brand`, `Category` | `products/product_service`, `brands/brand_service`, `search/*` | Xóa brand hoặc category sẽ **xóa luôn sản phẩm** (`dependent: :destroy`) |
| **Catalog phụ** | `ProductReview`, `ProductWishlist`, `ProductComparison(+Item)` | Logic nằm trong controller | |
| **Inventory** | `StockMovement`, `StockAlert` | `stock_alerts/*` (9 service) | Thay đổi tồn kho của **product** sinh ra `StockMovement` và alert. Tồn kho của **variant** thì không |
| **Cart** | `Cart` (`active` / `abandoned` / `completed`), `CartItem` | `carts/cart_service` | Không có code nào đặt `completed`. Cart không liên kết với Order |
| **Order** | `Order`, `OrderItem` | `orders/order_{creation,confirmation,cancellation}_service`, `shipping_service`, `delivery_service` | Domain trung tâm |
| **Payment** | `Payment`, `PaymentMethod` | `payments/payment_processing_core_service` (+ facade, webhook, `payment_method_*`) | **Toàn bộ là giả lập** ([KI-011](../known-issues.md#ki-011)) |
| **Pricing** | `Discount`, `Coupon`, `Promotion` | `discounts/*`, `validators/promotion_validator` | Giới hạn lượt dùng được đếm nguyên tử (#58, [KI-010](../known-issues.md#ki-010)). Apply promotion qua API đang hỏng ([KI-030](../known-issues.md#ki-030)) |
| **Fulfilment** | `ShippingZone`, `ShippingMethod`, `ShippingZoneMethod`, `TaxRate` | `shipping/shipping_cost_calculator_service`, `tax/tax_calculator_service` | |
| **Returns** | `ReturnRequest`, `ReturnItem` | `returns/return_processing_service` | Chưa có hoàn tiền ([KI-012](../known-issues.md#ki-012)) |
| **Notification** | `Notification` (21 loại) | Không có module riêng | Mỗi domain tự gọi `Notification.create!` |
| **Users** | `UserAddress` | `users/profile_*`, `users/address_*`, `address/address_validation_service` | |
| **Statistics** | Không có model | Không có service | Query viết trực tiếp trong [statistics_controller.rb](../../app/controllers/api/v1/statistics_controller.rb) |

**Thật hay giả lập**
- **Payment gateway:** gateway online (`stripe`, `paypal`, `wallet`) được giả lập bằng `SecureRandom`, nên thanh toán hoàn tất ngay. Với phương thức offline (`cash_on_delivery`, `bank_transfer`), payment chờ ở `pending` cho tới khi admin xác nhận đã nhận tiền qua `POST /payments/:id/confirm` (#60, [KI-025](../known-issues.md#ki-025)).
- **Email:** chỉ email xác minh tài khoản là gửi thật (`EmailVerificationMailer`). Dev dùng letter_opener, còn SMTP production chưa cấu hình. "Email" thông báo đơn hàng thực ra chỉ ghi log.
- **Job nền:**
  - `JwtCleanupJob` chạy cron lúc 02:00 mỗi ngày ([schedule.yml](../../config/schedule.yml)).
  - `StockAlertNotificationJob` được enqueue khi có alert.

## State machines

### Order
Đơn có **hai cột trạng thái độc lập** (từ #53, [KI-007](../known-issues.md#ki-007)):
- `status` theo dõi tiến độ giao hàng ([order.rb:39](../../app/models/order.rb)). Cột này chỉ đổi qua các service confirm/ship/deliver/cancel, mỗi bước được kiểm tra bằng `can_be_*?`.
- `payment_status` theo dõi thanh toán ([order.rb:47](../../app/models/order.rb)). Cột này chỉ đổi qua callback của Payment.

Thanh toán không đẩy đơn tiến hay lùi, và giao hàng không đòi phải trả tiền trước.

**`status`: giao hàng**

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> confirmed: OrderConfirmationService
  confirmed --> shipped: ShippingService
  shipped --> delivered: DeliveryService
  pending --> cancelled
  confirmed --> cancelled
  shipped --> cancelled
```

**`payment_status`: thanh toán**

```mermaid
stateDiagram-v2
  [*] --> unpaid
  unpaid --> paid: Payment completed (online, hoặc admin xác nhận tiền offline)
  unpaid --> payment_failed: Payment failed/cancelled
  payment_failed --> paid: lần trả sau thành công
  paid --> partially_refunded: hoàn một phần
  paid --> refunded: hoàn toàn bộ
```

- **Trả tiền** (`can_be_paid?`): đơn chưa hủy, đang `unpaid` hoặc `payment_failed`, ở bất kỳ bước giao hàng nào. Ví dụ: trả trước rồi giao, hoặc giao rồi mới thu tiền.
- **Hoàn tiền** đi qua `POST /payments/:id/refund`, và chỉ áp dụng cho payment đang `completed`. Vì vậy sau một lần hoàn một phần thì không hoàn tiếp được. Đơn đã giao rồi được hoàn tiền thì thành `delivered / refunded`.
- **`PATCH /orders/:id`** không đổi được trạng thái nào. Gửi `status` sẽ nhận 422 ([KI-008](../known-issues.md#ki-008)).

### Payment
- Các trạng thái: `pending`, `processing`, `completed`, `failed`, `cancelled`, `refunded`, `partially_refunded` ([payment.rb:35](../../app/models/payment.rb)).
- Các helper `mark_as_*!` **không kiểm tra bước chuyển hợp lệ**.
- Callback `sync_order_payment_status` ([payment.rb:256](../../app/models/payment.rb)) chỉ cập nhật `payment_status` của Order, không đụng `status`.
- `PATCH /payments/:id` không đổi được `status` hay `transaction_id`. Hoàn tiền đi qua action `refund`.

### Return request
Guard nằm trong các method `approve!` / `reject!` / `cancel!` / `complete!` của [return_request.rb](../../app/models/return_request.rb).

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> approved
  pending --> rejected
  pending --> cancelled
  approved --> cancelled
  approved --> processing
  processing --> completed: cộng lại tồn kho (chưa hoàn tiền)
```

## Coupling giữa các domain

Đây là thông tin quan trọng nhất nếu định tách microservice.

```mermaid
flowchart TD
  OC[Order creation] -->|cùng transaction, with_lock| INV[Product/Variant stock]
  INV -->|after_update callback| SA[StockAlert]
  SA -->|perform_later| NJ[StockAlertNotificationJob]
  OC -.->|không chạy qua API: thiếu country_code| SH[Shipping cost]
  OC -.-> TX[Tax]
  PAY[Payment] -->|model callback| ORD[Order.status]
  ORD -->|apply_discount| DIS[Discount]
  PRO[Promotion benefit] -->|tạo OrderItem miễn phí, không trừ kho| ORD
  CAN[Cancellation] --> INV
  RET[Return processing] --> INV
  CONF[Confirm/Ship/Deliver] -->|Notification.create! trực tiếp| NOTI[Notification]
  CAN --> NOTI
  SA --> NOTI
```

| Điểm nối | Kiểu | Vị trí | Mức độ khó khi tách |
|---|---|---|---|
| Order → Stock | Đồng bộ, **cùng transaction DB** | `order_creation_service.rb` (bước trừ kho), `product.rb:88` | **Cao.** Cần saga hoặc cơ chế giữ hàng (reservation) |
| Payment → Order | Callback của ActiveRecord | `payment.rb:256` | Trung bình. Chuyển thành domain event |
| Mọi domain → Notification | Ghi trực tiếp vào bảng | `order_confirmation_service.rb:84`, `shipping_service.rb:75`, `delivery_service.rb:73`, `order_cancellation_service.rb` | **Thấp.** Không nằm trên luồng chính, chỉ cần event một chiều. Là **ứng viên tách đầu tiên** |
| Product → Search index | Async qua Active Job | `product.rb:43`, [reindexes_products_on_rename.rb](../../app/models/concerns/reindexes_products_on_rename.rb) | Thấp. Đã là async và có fallback sang SQL |
| Order → Discount | Đồng bộ | `order.rb:153` | Trung bình |
| Stock → StockAlert | `after_update` callback | `product.rb:76, 165` | Trung bình |

**Lưu ý khi đọc luồng tạo đơn:**
- `order_create_params` chỉ nhận `customer_name`, `customer_email`, `customer_phone` ([orders_controller.rb:213](../../app/controllers/api/v1/orders/orders_controller.rb)). Vì vậy các nhánh tính phí ship và thuế trong `OrderCreationService` **không bao giờ chạy** khi gọi qua API.
- Việc tạo đơn **không** áp discount, **không** tạo payment, **không** gửi notification. Mỗi bước này là một endpoint riêng.
