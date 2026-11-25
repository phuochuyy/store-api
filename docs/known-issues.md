# Known issues

> Cập nhật theo commit: `3ed8915` · Ngày: 2026-11-25

Danh sách lỗi và rủi ro phát hiện khi đọc code. **Mỗi lỗi chỉ được mô tả ở đây.** Các tài liệu khác (roadmap, domain map) trỏ tới mã `KI-xxx` thay vì chép lại nội dung.

**Mức độ**
- **Critical**: người dùng thường làm được việc của admin hoặc làm sai lệch dữ liệu tiền/kho.
- **High**: rò rỉ dữ liệu, tính năng hỏng hoàn toàn, hoặc hỏng trên DB mục tiêu.
- **Medium**: sai nghiệp vụ, hoặc lỗ hổng chỉ lộ ra khi có thêm điều kiện khác.
- **Low**: nhất quán, tài liệu, code chết.

**Xác minh**
- ✅ **chạy thật**: đã tái hiện bằng request spec hoặc lệnh, chạy ngày 2026-11-25.
- ✅ **đọc code**: đã đọc đúng dòng code liên quan, nhưng chưa chạy.
- ⚠️ **chưa xác minh**

Khi sửa xong một lỗi, đổi cột *Trạng thái* thành `fixed (#PR)`. Đừng xóa dòng, để giữ lịch sử.

## Tổng quan

| ID | Mức độ | Tóm tắt | Xác minh | Trạng thái |
|---|---|---|---|---|
| [KI-001](#ki-001) | Critical | Customer tự duyệt/từ chối/hoàn tất yêu cầu đổi trả | ✅ chạy thật | open |
| [KI-002](#ki-002) | High | Toàn bộ API variants và addresses trả 500 | ✅ chạy thật | open |
| [KI-003](#ki-003) | High | `authorize!` không dừng action; truyền class thì luôn 403 | ✅ chạy thật | open |
| [KI-004](#ki-004) | High | IDOR: xem được payment của người khác | ✅ chạy thật | open |
| [KI-005](#ki-005) | High | IDOR + crash ở order items controller | ✅ chạy thật / đọc code | open |
| [KI-006](#ki-006) | High | MySQL/Aurora: logout không thu hồi được token (JWT > 255 ký tự) | ✅ chạy thật (MySQL 8.4) | open |
| [KI-007](#ki-007) | High | Đơn đã `paid` không thể confirm/ship (kẹt trạng thái) | ✅ chạy thật | open |
| [KI-008](#ki-008) | Medium | Admin `PATCH` đặt `status` order/payment tùy ý, bỏ qua state machine | ✅ đọc code | open |
| [KI-009](#ki-009) | Medium | Sentry không lọc password/token (`before_send` bị ghi đè) | ✅ đọc code | open |
| [KI-010](#ki-010) | Medium | Giới hạn lượt dùng discount không bao giờ được áp dụng | ✅ đọc code | open |
| [KI-011](#ki-011) | Medium | Webhook thanh toán: không có route, chữ ký giả, cột không tồn tại | ✅ đọc code | open |
| [KI-012](#ki-012) | Medium | Hoàn tất đổi trả / hủy đơn không hoàn tiền | ✅ đọc code | open |
| [KI-013](#ki-013) | Medium | `docker-compose.prod.yml` không kết nối được DB | ✅ đọc code | open |
| [KI-014](#ki-014) | Low | Doanh thu dashboard tính cả đơn đã hủy | ✅ đọc code | open |
| [KI-015](#ki-015) | Low | Swagger lệch: yaml 88 path, json 59 path | ✅ chạy thật | open |
| [KI-016](#ki-016) | Low | Blacklist JWT "fail open" khi cả Redis và DB lỗi | ✅ đọc code | open |
| [KI-017](#ki-017) | Low | Code chết và lớp trùng lặp | ✅ đọc code | open |
| [KI-018](#ki-018) | Low | Phân quyền và pagination làm theo nhiều kiểu khác nhau | ✅ đọc code | open |
| [KI-019](#ki-019) | Low | `make docs` gọi rake task không tồn tại | ✅ chạy thật | open |
| [KI-020](#ki-020) | Medium | `.gitignore` bỏ qua mọi spec mới, chỉ giữ các file trong whitelist | ✅ chạy thật | open |

---

## Chi tiết

### KI-001
**Customer tự thao tác được trên yêu cầu đổi trả của chính mình** · Critical

- **Ở đâu:** [returns_controller.rb](../app/controllers/api/v1/returns_controller.rb) các action `approve`/`reject`/`complete` (dòng 52, 63, 77). Cả ba gọi `authorize!` ở đầu thân action.
- **Vì sao:** xem [KI-003](#ki-003). `authorize!` render 403 nhưng action vẫn chạy tiếp và gọi `approve!` / `process_return`.
- **Tái hiện:** customer gửi `PATCH /api/v1/returns/:id/approve` với return request của mình. Response trả 500 (DoubleRenderError), **nhưng trong DB `status` đã thành `approved`.** Với `complete`, hệ thống còn cộng lại tồn kho.
- **Hướng sửa:** dùng `before_action` + policy (`ReturnRequestPolicy`), hoặc `return unless authorize!(...)`. Viết request spec cho cả hai vai trò.

### KI-002
**Toàn bộ API variants và addresses trả 500** · High

- **Ở đâu:** hai controller kế thừa `ApplicationController` thay vì `Api::V1::BaseController`, nên không có `authenticate_user!`, `current_user` hay `authorize!`:
  - [variants_controller.rb:6](../app/controllers/api/v1/products/variants_controller.rb)
  - [addresses_controller.rb:5](../app/controllers/api/v1/addresses_controller.rb)
- **Tái hiện:** `GET /api/v1/products/:id/variants`, `POST /api/v1/addresses/validate` và `GET /api/v1/addresses/autocomplete` đều trả 500 `undefined method 'authenticate_user!'`.
- **Hướng sửa:** đổi lớp cha. Sau đó lỗi [KI-003](#ki-003) sẽ lộ ra ngay ở variants. Thêm một spec kiểm tra mọi controller trong `Api::V1` (trừ `HealthController`) đều kế thừa `Api::V1::BaseController`.

### KI-003
**`authorize!` không dừng action; truyền class thì luôn 403** · High

- **Ở đâu:** [authorization.rb:9-17](../app/controllers/concerns/api/authorization.rb). `render_error(...) && return` chỉ thoát khỏi `authorize!`, không thoát khỏi action đã gọi nó.
- **Lỗi kèm theo:** `authorize! :create, ProductVariant` ([variants_controller.rb:24](../app/controllers/api/v1/products/variants_controller.rb)) truyền class. [`TokenValidationService.authorize`](../app/services/auth/token_validation_service.rb) dựng tên policy từ `resource.class.name`, ra `ClassPolicy` → NameError → `"Authorization policy not found"`. **Admin cũng bị chặn** (đã chạy thật).
- **Hướng sửa:** `authorize!` trả về boolean và chỉ được gọi trong `before_action`, hoặc raise một exception riêng (`NotAuthorizedError`) để [ErrorHandling](../app/controllers/concerns/error_handling.rb) xử lý. Hỗ trợ truyền class (`resource.is_a?(Class) ? resource : resource.class`).

### KI-004
**IDOR: xem được payment của người khác** · High

- **Ở đâu:** [payments_controller.rb:7-9, 17](../app/controllers/api/v1/payments/payments_controller.rb). `show` không nằm trong `admin_only!` và cũng không kiểm tra `payment.order.user_id`.
- **Tái hiện:** customer A gọi `GET /api/v1/payments/:id` với payment của customer B và nhận 200, kèm thông tin order và payment method.

### KI-005
**Order items controller: IDOR và crash** · High

- **Ở đâu:** [orders/items_controller.rb](../app/controllers/api/v1/orders/items_controller.rb)
  - `set_order_item` / `set_order` (dòng 54-62) không kiểm tra chủ sở hữu. Customer xem được item của đơn người khác (✅ chạy thật, 200). Theo code, update/destroy cũng không có kiểm tra nào.
  - `create`/`update` gọi `@order_item.phone`, một association không tồn tại (tàn dư khi model còn tên "phone"), nên ném NoMethodError (✅ đọc code).
  - Controller dùng `render json:` thô, không theo envelope `render_success`/`render_error`.
- **Hướng sửa:** scope theo `current_user.orders` (admin thì không cần), đổi sang `product`, dùng envelope chuẩn.

### KI-006
**MySQL/Aurora: logout không thu hồi được token** · High

- **Ở đâu:** `jwt_blacklist_tokens.token` là `t.string` ([schema.rb:134](../db/schema.rb)). Trên PostgreSQL kiểu này không giới hạn độ dài, nhưng trên MySQL nó thành `VARCHAR(255)`. Access token thật dài **272** ký tự, refresh token **257** (đo bằng `Auth::AuthService.generate_tokens` có `device_id` và `ip_address`).
- **Tái hiện trên MySQL 8.4:** `JwtBlacklistToken.create!(token: <access token>)` → `ActiveRecord::ValueTooLong: 1406 Data too long for column 'token'`.
- **Vì sao test không bắt được:** [BlacklistService](../app/services/auth/jwt/blacklist_service.rb) (dòng 33-35) nuốt exception và trả về `false`, nên logout vẫn trả về thành công nhưng token vẫn dùng được tới khi hết hạn. Helper trong spec ([jwt_helper.rb](../spec/support/jwt_helper.rb)) tạo token ngắn hơn (189 ký tự), nên CI MySQL vẫn xanh.
- **Hướng sửa:** lưu `token_digest` (SHA256, 64 ký tự) thay vì token thô. Redis cache ([cache_service.rb](../app/services/auth/jwt/cache_service.rb)) đã làm như vậy. Cách khác là lưu `jti`. Kiểm tra luôn `password_reset_tokens.token` và `users.email_verification_token`.

### KI-007
**Đơn đã thanh toán bị kẹt trạng thái** · High

- **Ở đâu:** khi payment chuyển sang `completed`, callback [payment.rb:254](../app/models/payment.rb) đổi order sang `paid`. Nhưng [order.rb:81](../app/models/order.rb) `can_be_confirmed?` chỉ chấp nhận `pending`, và `can_be_shipped?` chỉ chấp nhận `confirmed`.
- **Hệ quả:** đơn đã trả tiền không thể confirm hay ship. Luồng thanh toán trước rồi giao hàng không đi được.
- **Hướng sửa:** thiết kế lại state machine. Tách `payment_status` ra khỏi `fulfillment_status`, hoặc cho phép `paid → confirmed`. Xem [02-domain-map.md](onboarding/02-domain-map.md#order).

### KI-008
**Admin cập nhật `status` tùy ý** · Medium

- **Ở đâu:** [orders_controller.rb:197](../app/controllers/api/v1/orders/orders_controller.rb) (`order_params` cho phép `status`), [payments_controller.rb:186](../app/controllers/api/v1/payments/payments_controller.rb) (`payment_update_params` cho phép `status` và `transaction_id`).
- **Hệ quả:** bỏ qua mọi kiểm tra chuyển trạng thái, không trả lại hàng vào kho, không tạo notification. Chỉ cần đổi payment sang `refunded` là order bị đổi theo luôn.

### KI-009
**Sentry không lọc dữ liệu nhạy cảm** · Medium

- **Ở đâu:** [config/initializers/sentry.rb](../config/initializers/sentry.rb). `config.before_send` được gán ở dòng 17 (lọc `password`, `token`) rồi **gán lại** ở dòng 38. Chỉ lambda thứ hai có hiệu lực.
- **Hệ quả:** ở production, password và token trong request body có thể bị gửi lên Sentry.

### KI-010
**Giới hạn lượt dùng discount không có tác dụng** · Medium

- [`Order#apply_discount`](../app/models/order.rb) (dòng 147) không gọi `increment_usage!`.
- [`Coupon#use!`](../app/models/coupon.rb) (dòng 35) có gọi, nhưng chính nó không được ai gọi.
- [`Discount#increment_usage!`](../app/models/discount.rb) (dòng 86) và [`Promotion#increment_usage!`](../app/models/promotion.rb) (dòng 78) dùng `update!(used_count: used_count + 1)`. Khi có request đồng thời, bộ đếm bị mất lượt (lost update). Nên dùng `increment_counter` hoặc `with_lock`.
- Promotion tặng sản phẩm miễn phí tạo order item ([promotion_benefit_service.rb:76](../app/services/discounts/promotion_benefit_service.rb)) nhưng không trừ tồn kho.

### KI-011
**Webhook thanh toán chưa dùng được** · Medium

- Không có route nào trong [routes.rb](../config/routes.rb) trỏ tới webhook.
- Kiểm tra chữ ký là giả lập, luôn trả về thành công ([payment_webhook_service.rb:78-91](../app/services/payments/payment_webhook_service.rb)).
- Tìm `Payment.find_by(gateway_transaction_id:)` (dòng 183), nhưng bảng `payments` chỉ có `transaction_id`.
- Đặt `status: 'chargeback'` (dòng 170), giá trị này không có trong enum.
- Không chống trùng event (thiếu idempotency).
- Bối cảnh: mọi gateway đều là giả lập. [payment_processing_core_service.rb:129-174](../app/services/payments/payment_processing_core_service.rb) trả về `transaction_id` sinh từ `SecureRandom`.

### KI-012
**Không có luồng hoàn tiền** · Medium

- Hoàn tất đổi trả có cộng lại tồn kho, nhưng phần hoàn tiền vẫn là `TODO` ([return_processing_service.rb:147](../app/services/returns/return_processing_service.rb)).
- Hủy đơn ([order_cancellation_service.rb](../app/services/orders/order_cancellation_service.rb)) trả lại tồn kho, nhưng không refund payment và không hoàn lại lượt dùng discount.

### KI-013
**`docker-compose.prod.yml` không kết nối được DB** · Medium

- Service `web` truyền `DATABASE_PASSWORD`, nhưng [database.yml:104](../config/database.yml) đọc `STORE_API_DATABASE_PASSWORD`.
- Service `web` không đặt `DATABASE_PORT`, nên `database.yml` dùng mặc định **5433** (dòng 28). Postgres trong mạng compose lại lắng nghe ở 5432.
- `Dockerfile` hiện là bản cho development (`RAILS_ENV=development`, chạy bằng root) và không có worker Sidekiq. Xem [04-infra-and-ops.md](onboarding/04-infra-and-ops.md).

### KI-014
**Doanh thu tính cả đơn đã hủy** · Low

[statistics_controller.rb:10](../app/controllers/api/v1/statistics_controller.rb) dùng `Order.sum(:total_amount)` không lọc theo trạng thái.

### KI-015
**Swagger lệch so với route thật** · Low

- [swagger.yaml](../swagger/v1/swagger.yaml) có 88 path, còn [swagger.json](../swagger/v1/swagger.json) (do `rails swagger:merge` sinh ra, và là file `/api-docs` đang hiển thị) chỉ có 59.
- 29 path bị thiếu gồm: variants, shipping, tax, returns, addresses, reviews, wishlists, comparisons, users/profile, users/addresses.
- Swagger dùng `/api/v1/return_requests/...`, còn route thật là `/api/v1/returns/...`.
- Chỉ 3 request spec (carts, orders, payments) kiểm tra response theo schema.
- Lệnh kiểm tra: `ruby -ryaml -rjson -e 'y=YAML.load_file("swagger/v1/swagger.yaml");j=JSON.parse(File.read("swagger/v1/swagger.json"));p y["paths"].size, j["paths"].size'`

### KI-016
**Blacklist JWT "fail open"** · Low

[blacklist_service.rb:38-52](../app/services/auth/jwt/blacklist_service.rb): khi cả Redis và DB đều lỗi, `blacklisted?` trả về `false`, tức là chấp nhận token đã bị thu hồi. Code đang chủ ý ưu tiên tính sẵn sàng. Cần quyết định có chấp nhận đánh đổi này không và ghi lại lý do.

### KI-017
**Code chết và lớp trùng lặp** · Low

- **Không ai gọi:**
  - `Orders::NotificationService`, kéo theo 6 service `Order*NotificationService` và `BulkOrderNotificationService`, vì chúng chỉ được gọi từ đó.
  - `Users::AddressService`, `Categories::CategoryService`, `CartService.validate_cart_for_checkout`, `Coupon#use!`.
- **Không có model:** bảng `payment_histories` có serializer nhưng không có model, nên các method `track_*` trong [payment.rb](../app/models/payment.rb) không bao giờ chạy.
- **Lớp chỉ chuyển tiếp:** `Payments::PaymentProcessorService` chỉ gọi thẳng sang core service và webhook service.
- **Action không có route:** nhiều action trong `notifications_controller` (`unread_count`, `recent`, `send_daily_summary`…) và `stock_alerts_controller` (`resolve`, `dismiss`, `bulk_operation`…).
- **Method công khai nhầm:** một số helper để `public` lẽ ra phải `private` (payments, payment methods, comparisons, reviews, statistics). `ShippingController#methods` ghi đè `Object#methods` của Ruby.

### KI-018
**Phân quyền và pagination làm theo nhiều kiểu** · Low

- **Phân quyền có 4 kiểu:**
  1. Policy qua `before_action` (products, brands).
  2. `admin_only!` (orders, payments, discounts, promotions, stock alerts, statistics). Lưu ý `DiscountPolicy` và `PromotionPolicy` tồn tại nhưng không được dùng.
  3. `ensure_admin!` tự viết riêng (categories).
  4. `authorize!` gọi giữa thân action (returns, variants). Đây là nguồn gốc của [KI-003](#ki-003).
- **Pagination có 3 dạng meta:**
  1. `Common::Pagination#pagination_meta`, giới hạn 100 bản ghi mỗi trang, có `has_next_page`/`has_prev_page`.
  2. Tự viết trong service (brands, products), không giới hạn.
  3. Dựng trực tiếp trong controller (orders, categories, payments).
- **Status code 422 lẫn lộn:** `:unprocessable_content` và `:unprocessable_entity`.

### KI-019
**`make docs` gọi task không tồn tại** · Low

[Makefile:180](../Makefile) gọi `rails swagger:docs`, nhưng chỉ có `swagger:merge`, `swagger:validate`, `swagger:generate`… Ngoài ra, README hướng dẫn `make docker-dev-up`, nhưng target này nằm trong `Makefile.docker`, không phải `Makefile`. Phải chạy `make -f Makefile.docker docker-dev-up`.

### KI-020
**`.gitignore` bỏ qua mọi spec mới** · Medium

- **Ở đâu:** [.gitignore:225](../.gitignore) có `spec/**/*_spec.rb`, sau đó chỉ whitelist khoảng 20 file cụ thể bằng các dòng `!spec/...`.
- **Hệ quả:** một spec mới, ví dụ `spec/models/discount_spec.rb` hay `spec/requests/api/v1/brands_spec.rb`, **bị git bỏ qua mà không có cảnh báo nào**. Test chạy được ở máy local nhưng không bao giờ lên CI.
- **Kiểm tra:** `git check-ignore -v spec/models/discount_spec.rb`.
- **Tạm thời:** `git add -f <file>`. **Hướng sửa:** xóa dòng `spec/**/*_spec.rb` và toàn bộ whitelist đi kèm. Đây nên là việc đầu tiên của giai đoạn 0, vì mọi bản sửa lỗi phía sau đều cần commit spec.
