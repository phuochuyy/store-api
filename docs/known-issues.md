# Known issues

> Cập nhật theo commit: `15319f3` · Ngày: 2026-11-25

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

Khi sửa xong một lỗi, đổi cột *Trạng thái* thành `fixed (#PR)` và thêm dòng **Đã sửa** vào phần chi tiết. Đừng xóa dòng, để giữ lịch sử.

**Tình hình hiện tại:** 29 lỗi đã ghi nhận, 13 đã sửa. Còn mở: 0 Critical, 1 High (KI-025), 5 Medium, 10 Low.

## Tổng quan

| ID | Mức độ | Tóm tắt | Xác minh | Trạng thái |
|---|---|---|---|---|
| [KI-001](#ki-001) | Critical | Customer tự duyệt/từ chối/hoàn tất yêu cầu đổi trả | ✅ chạy thật | fixed (#48, test #50) |
| [KI-002](#ki-002) | High | Toàn bộ API variants và addresses trả 500 | ✅ chạy thật | fixed (#49) |
| [KI-003](#ki-003) | High | `authorize!` không dừng action; truyền class thì luôn 403 | ✅ chạy thật | fixed (#48) |
| [KI-004](#ki-004) | High | IDOR: xem được payment của người khác | ✅ chạy thật | fixed (#52) |
| [KI-005](#ki-005) | High | IDOR + crash ở order items controller | ✅ chạy thật | fixed (#52) |
| [KI-006](#ki-006) | High | MySQL/Aurora: logout không thu hồi được token (JWT > 255 ký tự) | ✅ chạy thật (MySQL 8.4) | fixed (#55) |
| [KI-007](#ki-007) | High | Đơn đã `paid` không thể confirm/ship (kẹt trạng thái) | ✅ chạy thật | fixed (#53) |
| [KI-008](#ki-008) | Medium | Admin `PATCH` đặt `status` order/payment tùy ý, bỏ qua state machine | ✅ đọc code | fixed (#53) |
| [KI-009](#ki-009) | Low | Sentry không lọc password/token (`before_send` bị ghi đè) | ✅ chạy thật | fixed (#56) |
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
| [KI-020](#ki-020) | Medium | `.gitignore` bỏ qua mọi spec mới, chỉ giữ các file trong whitelist | ✅ chạy thật | fixed (#47) |
| [KI-021](#ki-021) | High | Ruby 3.4.5 dính CVE-2026-132825 (có thể dẫn tới RCE) | ✅ Brakeman 8.1.1 | fixed (#46) |
| [KI-022](#ki-022) | Medium | `POST /addresses/validate` báo mọi địa chỉ là hợp lệ | ✅ chạy thật | fixed (#49) |
| [KI-023](#ki-023) | Low | `db:schema:load` trên MySQL lỗi khi database đã có bảng | ✅ chạy thật | open |
| [KI-024](#ki-024) | Medium | Admin sửa order item không cập nhật tồn kho, kể cả với đơn đã giao | ✅ đọc code | open |
| [KI-025](#ki-025) | High | Thanh toán `bank_transfer` / `cash_on_delivery` / `wallet` luôn thất bại | ✅ chạy thật | open |
| [KI-026](#ki-026) | Low | `shipping_status` trả `not_shipped` cho đơn đã giao | ✅ chạy thật | open |
| [KI-027](#ki-027) | Medium | Confirm đơn tính tồn kho đã giữ hai lần: đơn mua hết kho không confirm được | ✅ chạy thật | fixed (#53) |
| [KI-028](#ki-028) | Low | CI: spec Elasticsearch thỉnh thoảng fail với "index already exists" | ✅ chạy thật (CI) | open |
| [KI-029](#ki-029) | Low | "Logout mọi phiên" bỏ sót token cấp trong cùng giây với lúc logout | ✅ đọc code | open |

---

## Chi tiết

### KI-001
**Customer tự thao tác được trên yêu cầu đổi trả của chính mình** · Critical

- **Ở đâu:** [returns_controller.rb](../app/controllers/api/v1/returns_controller.rb) các action `approve`/`reject`/`complete` (dòng 52, 63, 77). Cả ba gọi `authorize!` ở đầu thân action.
- **Vì sao:** xem [KI-003](#ki-003). `authorize!` render 403 nhưng action vẫn chạy tiếp và gọi `approve!` / `process_return`.
- **Tái hiện:** customer gửi `PATCH /api/v1/returns/:id/approve` với return request của mình. Response trả 500 (DoubleRenderError), **nhưng trong DB `status` đã thành `approved`.** Với `complete`, hệ thống còn cộng lại tồn kho.
- **Hướng sửa:** dùng `before_action` + policy (`ReturnRequestPolicy`), hoặc `return unless authorize!(...)`. Viết request spec cho cả hai vai trò.
- **Đã sửa:** #48 sửa tận gốc ở [KI-003](#ki-003). Policy vốn đã chỉ cho admin, chỉ là trước đó không có tác dụng. #50 thêm contract spec: chủ yêu cầu gọi approve/reject/complete nhận 403, trạng thái và tồn kho không đổi ([returns_spec.rb](../spec/requests/api/v1/returns_spec.rb)).

### KI-002
**Toàn bộ API variants và addresses trả 500** · High

- **Ở đâu:** hai controller kế thừa `ApplicationController` thay vì `Api::V1::BaseController`, nên không có `authenticate_user!`, `current_user` hay `authorize!`:
  - [variants_controller.rb:6](../app/controllers/api/v1/products/variants_controller.rb)
  - [addresses_controller.rb:5](../app/controllers/api/v1/addresses_controller.rb)
- **Tái hiện:** `GET /api/v1/products/:id/variants`, `POST /api/v1/addresses/validate` và `GET /api/v1/addresses/autocomplete` đều trả 500 `undefined method 'authenticate_user!'`.
- **Hướng sửa:** đổi lớp cha. Sau đó lỗi [KI-003](#ki-003) sẽ lộ ra ngay ở variants. Thêm một spec kiểm tra mọi controller trong `Api::V1` (trừ `HealthController`) đều kế thừa `Api::V1::BaseController`.
- **Đã sửa:** #49 đổi lớp cha cho cả hai controller. [controller_inheritance_spec.rb](../spec/controllers/api/v1/controller_inheritance_spec.rb) chặn lỗi này quay lại, và in tên controller sai. Khi endpoint chạy được, contract spec phát hiện thêm `price` của variant trả về number thay vì string như schema (đã sửa), và lỗi [KI-022](#ki-022).

### KI-003
**`authorize!` không dừng action; truyền class thì luôn 403** · High

- **Ở đâu (trước #48):** [authorization.rb](../app/controllers/concerns/api/authorization.rb) `authorize!`. `render_error(...) && return` chỉ thoát khỏi `authorize!`, không thoát khỏi action đã gọi nó.
- **Lỗi kèm theo:** `authorize! :create, ProductVariant` ([variants_controller.rb:23](../app/controllers/api/v1/products/variants_controller.rb)) truyền class. [`TokenValidationService.authorize`](../app/services/auth/token_validation_service.rb) dựng tên policy từ `resource.class.name`, ra `ClassPolicy` → NameError → `"Authorization policy not found"`. **Admin cũng bị chặn** (đã chạy thật).
- **Hướng sửa:** `authorize!` trả về boolean và chỉ được gọi trong `before_action`, hoặc raise một exception riêng (`NotAuthorizedError`) để [ErrorHandling](../app/controllers/concerns/error_handling.rb) xử lý. Hỗ trợ truyền class (`resource.is_a?(Class) ? resource : resource.class`).
- **Đã sửa:** #48 chọn cách raise.
  - `authorize!` và `admin_only!` raise `Api::Authorization::NotAuthorizedError`, và `rescue_from` trả 403, nên action dừng dù được gọi ở đâu.
  - `TokenValidationService.authorize` nhận cả class.
  - Policy được tìm bằng `safe_constantize`. Code cũ `rescue NameError` nuốt luôn `NoMethodError` bên trong policy và báo nhầm thành "policy not found".
  - Các action thử trong spec cũ tự thêm `return if performed?`, nên che mất lỗi. Spec mới đã bỏ dòng đó.

### KI-004
**IDOR: xem được payment của người khác** · High

- **Ở đâu:** [payments_controller.rb:7-9, 17](../app/controllers/api/v1/payments/payments_controller.rb). `show` không nằm trong `admin_only!` và cũng không kiểm tra `payment.order.user_id`.
- **Tái hiện:** customer A gọi `GET /api/v1/payments/:id` với payment của customer B và nhận 200, kèm thông tin order và payment method.
- **Đã sửa:** #52. `set_payment` trả 404 nếu người gọi không phải admin và không sở hữu đơn của payment đó. Dùng 404 thay vì 403 để không xác nhận là payment tồn tại, giống quy ước của orders và returns. `admin_only!` giờ chạy trước `set_payment`, nên customer gọi update/destroy/refund nhận 403 mà không cần tra payment. Contract spec ở [payments_spec.rb](../spec/requests/api/v1/payments_spec.rb).

### KI-005
**Order items controller: IDOR và crash** · High

- **Ở đâu:** [orders/items_controller.rb](../app/controllers/api/v1/orders/items_controller.rb)
  - `set_order_item` / `set_order` (dòng 54-62) không kiểm tra chủ sở hữu. Customer xem được item của đơn người khác (✅ chạy thật, 200). Theo code, update/destroy cũng không có kiểm tra nào.
  - `create`/`update` gọi `@order_item.phone`, một association không tồn tại (tàn dư khi model còn tên "phone"), nên ném NoMethodError (✅ đọc code).
  - Controller dùng `render json:` thô, không theo envelope `render_success`/`render_error`.
- **Hướng sửa:** scope theo `current_user.orders` (admin thì không cần), đổi sang `product`, dùng envelope chuẩn.
- **Thực tế tệ hơn đã ghi** (chạy thật trên code cũ):
  - Một customer khác **xóa được** item của đơn người khác (204).
  - Một customer khác **đổi được** `quantity` thành 99: update đã lưu xuống DB rồi mới crash ở `phone`. Response là 500, nhưng tổng tiền đơn đã thành 4950.
- **Đã sửa:** #52.
  - Chủ đơn và admin được **đọc**. Người khác nhận 404.
  - Chỉ admin được **sửa** (giống update và cancel của đơn). `admin_only!` chạy trước, nên customer nhận 403.
  - Update chỉ nhận `quantity`, đúng như Swagger mô tả. Cho đổi `product_id` sẽ giữ nguyên `unit_price` cũ.
  - Model `OrderItem` tự tính giá và tự cập nhật tổng tiền.
  - Response dùng envelope chuẩn. `DELETE` trả 200 thay vì 204.
  - Contract spec ở [order_items_spec.rb](../spec/requests/api/v1/order_items_spec.rb). Phần còn lại xem [KI-024](#ki-024).

### KI-006
**MySQL/Aurora: logout không thu hồi được token** · High

- **Ở đâu (trước #55):** `jwt_blacklist_tokens.token` là `t.string` ([schema.rb:134](../db/schema.rb)). Trên PostgreSQL kiểu này không giới hạn độ dài, nhưng trên MySQL nó thành `VARCHAR(255)`. Access token thật dài **272** ký tự, refresh token **257** (đo bằng `Auth::AuthService.generate_tokens` có `device_id` và `ip_address`).
- **Tái hiện trên MySQL 8.4:** `JwtBlacklistToken.create!(token: <access token>)` → `ActiveRecord::ValueTooLong: 1406 Data too long for column 'token'`.
- **Vì sao test không bắt được:** [BlacklistService](../app/services/auth/jwt/blacklist_service.rb) (dòng 33-35) nuốt exception và trả về `false`, nên logout vẫn trả về thành công nhưng token vẫn dùng được tới khi hết hạn. Helper trong spec ([jwt_helper.rb](../spec/support/jwt_helper.rb)) tạo token ngắn hơn (189 ký tự), nên CI MySQL vẫn xanh.
- **Hướng sửa:** lưu `token_digest` (SHA256, 64 ký tự) thay vì token thô. Redis cache ([cache_service.rb](../app/services/auth/jwt/cache_service.rb)) đã làm như vậy. Cách khác là lưu `jti`. Kiểm tra luôn `password_reset_tokens.token` và `users.email_verification_token`.
- **Hệ quả thật (phát hiện khi sửa):**
  - Nặng nhất là **xoay vòng refresh token không có tác dụng**: refresh token cũ dùng lại được cho tới khi hết hạn.
  - Access token vẫn dùng được sau khi logout nếu mốc logout trong Redis không che được nó: Redis sập, hoặc token được cấp trong cùng giây ([KI-029](#ki-029)).
- **Đã sửa:** #55.
  - Bảng chỉ lưu `token_digest` (SHA-256, 64 ký tự, unique index), không lưu token thô. Lộ bảng cũng không có token nào dùng được.
  - Migration băm các token còn hạn và xóa các dòng đã hết hạn. Đã chạy `up` và `down` trên PostgreSQL và MySQL.
  - [auth_revocation_spec.rb](../spec/requests/api/v1/auth_revocation_spec.rb) login qua API với device id dạng hash, nên token dài hơn 255 ký tự. Spec kiểm tra dùng lại refresh token và logout, khi có Redis và khi Redis sập. Trên MySQL, code cũ fail cả 4 test.
  - Hai cột token còn lại lưu chuỗi ngẫu nhiên 43 ký tự (`SecureRandom.urlsafe_base64(32)`), không vướng giới hạn.

### KI-007
**Đơn đã thanh toán bị kẹt trạng thái** · High

- **Ở đâu (trước #53):** khi payment chuyển sang `completed`, callback [payment.rb:254](../app/models/payment.rb) đổi order sang `paid`. Nhưng [order.rb:81](../app/models/order.rb) `can_be_confirmed?` chỉ chấp nhận `pending`, và `can_be_shipped?` chỉ chấp nhận `confirmed`.
- **Hệ quả:** đơn đã trả tiền không thể confirm hay ship. Luồng thanh toán trước rồi giao hàng không đi được.
- **Hướng sửa:** thiết kế lại state machine. Tách `payment_status` ra khỏi `fulfillment_status`, hoặc cho phép `paid → confirmed`. Xem [02-domain-map.md](onboarding/02-domain-map.md#order).
- **Đã sửa:** #53 chọn cách tách cột.
  - `orders.payment_status` (unpaid, paid, payment_failed, refunded, partially_refunded) là cột mới. `status` chỉ còn 5 trạng thái giao hàng.
  - Payment chỉ cập nhật `payment_status`, không đụng `status`. Một lần trả tiền thất bại không làm đơn đã `paid` bị hạ xuống.
  - Đơn trả tiền được ở mọi bước giao hàng, cho tới khi bị hủy hoặc đã trả xong. Hoàn tiền không xóa tiến độ giao hàng: đơn đã giao vẫn là `delivered`.
  - Migration chuyển các trạng thái thanh toán sang cột mới, rồi khôi phục tiến độ giao hàng từ `confirmed_at` / `shipped_at` / `delivered_at` / `cancelled_at`. Đã chạy `up` và `down` trên PostgreSQL và MySQL.
  - Spec luồng đầu cuối qua API ở [order_lifecycle_spec.rb](../spec/requests/api/v1/order_lifecycle_spec.rb).
  - **Phá vỡ tương thích:** client đọc trạng thái thanh toán ở `payment_status`. Xem sơ đồ mới ở [02-domain-map.md](onboarding/02-domain-map.md#order).

### KI-008
**Admin cập nhật `status` tùy ý** · Medium

- **Ở đâu (trước #53):** [orders_controller.rb:197](../app/controllers/api/v1/orders/orders_controller.rb) (`order_params` cho phép `status`), [payments_controller.rb:186](../app/controllers/api/v1/payments/payments_controller.rb) (`payment_update_params` cho phép `status` và `transaction_id`).
- **Hệ quả:** bỏ qua mọi kiểm tra chuyển trạng thái, không trả lại hàng vào kho, không tạo notification. Chỉ cần đổi payment sang `refunded` là order bị đổi theo luôn.
- **Đã sửa:** #53.
  - `PATCH /orders/:id` chỉ nhận thông tin liên hệ của khách. `PATCH /payments/:id` chỉ nhận `gateway_response`, `failure_reason` và `metadata`.
  - Gửi `status` (hoặc `payment_status`, `transaction_id`) nhận 422, kèm thông báo chỉ sang action đúng (confirm/ship/deliver/cancel, refund). Trước đây các trường này bị lờ đi mà không báo gì.
  - **Phá vỡ tương thích** với client đang gửi `status` qua `PATCH`.

### KI-009
**Sentry không lọc dữ liệu nhạy cảm** · Medium

- **Ở đâu (trước #56):** [config/initializers/sentry.rb](../config/initializers/sentry.rb). `config.before_send` được gán ở dòng 17 (lọc `password`, `token`) rồi **gán lại** ở dòng 38. Chỉ lambda thứ hai có hiệu lực.
- **Hệ quả:** ở production, password và token trong request body có thể bị gửi lên Sentry.
- **Đánh giá lại khi sửa (Medium → Low):** đọc mã nguồn sentry-ruby 7.2 cho thấy với cấu hình mặc định (`send_default_pii = false`), SDK không gửi request body hay query string, và luôn che các key cấp ngoài cùng như `auth`, `token`, `password`. Vì vậy hiện chưa có dữ liệu nào bị lộ. Rủi ro còn lại:
  - Bộ lọc của SDK chỉ xét key cấp ngoài cùng và không biết các term riêng của app. Khi bật thu thập body để debug, `user.password` lồng bên trong và `email` sẽ đi nguyên văn.
  - Dữ liệu gắn vào `extra` và breadcrumb luôn được gửi, bất kể cấu hình.
  - Lambda `before_send` thứ hai đọc `hint[:scope]`, nhưng SDK không bao giờ truyền key này, nên nó cũng không có tác dụng.
- **Đã sửa:** #56.
  - [sentry_scrubber.rb](../lib/sentry_scrubber.rb) che giá trị ở mọi độ sâu trong body, query, header, cookie, `extra`, `contexts` và breadcrumb. Danh sách term là `filter_parameters` của Rails (chính danh sách đang giữ cho log sạch), cộng thêm `authorization` và `cookie`.
  - [sentry_scrubber_spec.rb](../spec/lib/sentry_scrubber_spec.rb) cho event đi qua pipeline thật của SDK, có bật thu thập body. Với initializer cũ, cả 4 test đều fail.

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
- Lúc ghi nhận, chỉ 3 request spec (carts, orders, payments) kiểm tra response theo schema. Từ #49 đến #52 đã có thêm variants, addresses, returns và order items.
- **Lỗi gõ `get::`** ở 17 operation trong 12 file `swagger/v1/paths/*.yaml`: YAML đọc thành key `"get:"`, nên các thao tác GET đó không có trong tài liệu. Tìm bằng `grep -rn 'get::' swagger/v1/paths`.
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
- **Nhánh không bao giờ chạy:** `when 'square'` trong các service thanh toán, vì enum `gateway_type` không có `square` (xem [KI-025](#ki-025)).
- **Lớp chỉ chuyển tiếp:** `Payments::PaymentProcessorService` chỉ gọi thẳng sang core service và webhook service.
- **Action không có route:** nhiều action trong `notifications_controller` (`unread_count`, `recent`, `send_daily_summary`…) và `stock_alerts_controller` (`resolve`, `dismiss`, `bulk_operation`…).
- **Method công khai nhầm:** một số helper để `public` lẽ ra phải `private` (payments, payment methods, comparisons, reviews, statistics). `ShippingController#methods` ghi đè `Object#methods` của Ruby.

### KI-018
**Phân quyền và pagination làm theo nhiều kiểu** · Low

- **Phân quyền có 4 kiểu:**
  1. Policy qua `before_action` (products, brands).
  2. `admin_only!` (orders, payments, discounts, promotions, stock alerts, statistics). Lưu ý `DiscountPolicy` và `PromotionPolicy` tồn tại nhưng không được dùng.
  3. `ensure_admin!` tự viết riêng (categories).
  4. `authorize!` gọi giữa thân action (returns, variants). Đây là nguồn gốc của [KI-003](#ki-003). Từ #48, cách này đã an toàn, nhưng vẫn là một kiểu riêng cần gom về chung.
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
- **Đã sửa:** #47 xóa cả khối này và khối tương tự cho `spec/factories/**/*.rb`; factory mới cũng từng bị ẩn y như vậy. [bin/check-gitignore](../bin/check-gitignore) chạy trong job `lint` của CI và trong `bin/ci`. Script báo lỗi, kèm số dòng của rule gây ra, nếu có rule nào ẩn file mới trong `spec/`.

### KI-021
**Ruby 3.4.5 dính CVE-2026-132825** · High

- **Ở đâu:** [.ruby-version](../.ruby-version) và `FROM ruby:3.4.5-slim` trong [Dockerfile](../Dockerfile).
- **Lỗi:** tràn bộ nhớ heap khi đổi chữ hoa/thường của chuỗi, có thể dẫn tới thực thi code từ xa. Ảnh hưởng Ruby 3.4.0 tới 3.4.12. Các nguồn ghi mức độ khác nhau: Critical hoặc High (7.4).
- **Phát hiện thế nào:** Brakeman 8.1.1 có thêm kiểm tra `Ruby2Shell`. `bin/brakeman` chạy với `--ensure-latest`, nên CI fail ngay khi có bản Brakeman mới. Chỉ nâng Brakeman thì nó lại báo lỗ hổng này.
- **Đã sửa:** #46 nâng lên Ruby 3.4.13 (bản vá phát hành 18/11/2026) và Brakeman 8.1.1.
- **Bài học:** vì `--ensure-latest`, mỗi bản Brakeman mới đều làm mọi PR đỏ cho tới khi được nâng lên. Gặp job `security` đỏ hàng loạt thì kiểm tra điều này trước.

### KI-022
**`POST /api/v1/addresses/validate` báo mọi địa chỉ là hợp lệ** · Medium

- **Ở đâu:** [address_validation_service.rb](../app/services/address/address_validation_service.rb) `validate`. `basic_validation` luôn trả `success: true` và báo lỗi qua `valid: false`, nhưng `validate` chỉ dừng khi `success` là false.
- **Hệ quả:** địa chỉ thiếu city, với country code `usa`, vẫn nhận `valid: true` và được chuẩn hóa. Lỗi bị che vì endpoint trả 500 ([KI-002](#ki-002)).
- **Đã sửa:** #49 dừng khi `valid` là false. Contract spec ở [addresses_spec.rb](../spec/requests/api/v1/addresses_spec.rb).

### KI-023
**`db:schema:load` trên MySQL lỗi khi database đã có bảng** · Low

- **Tái hiện:** chạy `DB_ADAPTER=trilogy DATABASE_PORT=3307 RAILS_ENV=test bin/rails db:schema:load` hai lần. Lần hai báo `Cannot drop table 'active_storage_blobs' referenced by a foreign key constraint ... on table 'active_storage_variant_records'`.
- **Vì sao:** MySQL không làm theo `force: :cascade` khi DROP TABLE có foreign key trỏ tới.
- **Ảnh hưởng:** chỉ ở máy local. CI luôn nạp schema vào database trống.
- **Tạm thời:** `bin/rails db:drop db:create db:schema:load`.

### KI-024
**Admin sửa order item không cập nhật tồn kho** · Medium

- **Ở đâu:** [orders/items_controller.rb](../app/controllers/api/v1/orders/items_controller.rb) `create`/`update`/`destroy` (chỉ admin, từ #52).
- **Lỗi:**
  - Thêm, bớt hoặc đổi số lượng item **không đụng tới tồn kho**. Luồng tạo đơn ([order_creation_service.rb](../app/services/orders/order_creation_service.rb)) thì có trừ kho, trong `with_lock`.
  - Sửa được cả đơn đã `shipped` hay `delivered`.
- **Lỗi phụ:** route lồng `/api/v1/orders/:order_id/items/:id` bỏ qua `order_id`. Quyền sở hữu vẫn được kiểm tra theo đơn thật của item, nên không phải lỗ hổng.
- **Hướng sửa:** chỉ cho sửa khi đơn còn `pending`, và đi qua `Product#reduce_stock` / `add_stock` như luồng tạo và hủy đơn.

### KI-025
**Thanh toán bằng `bank_transfer`, `cash_on_delivery` hoặc `wallet` luôn thất bại** · High

- **Ở đâu:** enum `gateway_type` ở [payment_method.rb:33](../app/models/payment_method.rb) có 5 loại. Nhưng `process_with_gateway` ([payment_processing_core_service.rb:66](../app/services/payments/payment_processing_core_service.rb)) chỉ xử lý `stripe`, `paypal` và `square`, các loại khác rơi vào `else`.
- **Tái hiện:** gọi `POST /api/v1/payments` với một payment method thuộc mỗi loại.
  - `stripe` và `paypal` trả 201, payment `completed`.
  - Ba loại còn lại trả 422 `Unsupported gateway type: ...`. Payment bị lưu là `failed`, còn `payment_status` của đơn thành `payment_failed`.
  - Admin vẫn tạo được payment method thuộc các loại này, nên lỗi chỉ lộ ra khi khách trả tiền.
- **Lỗi phụ:** `square` không có trong enum, nên mọi nhánh `when 'square'` đều là code chết. Có 6 câu `case` như vậy, rải ở các file:
  - `process_with_gateway` và `process_refund_with_gateway` trong core service.
  - `test_payment_method_connectivity` và `validate_gateway_specific_config` trong [payment_method_validation_service.rb](../app/services/payments/payment_method_validation_service.rb).
  - Hai chỗ trong [payment_webhook_service.rb](../app/services/payments/payment_webhook_service.rb).
- **Hướng sửa:**
  - `cash_on_delivery` và `bank_transfer` không đi qua gateway. Tạo payment ở trạng thái `pending`, rồi admin xác nhận đã nhận tiền bằng một action riêng để chuyển sang `completed`.
  - `wallet`: bỏ khỏi enum, hoặc giả lập như `stripe`.
  - Gom các loại gateway vào một registry duy nhất thay cho 6 câu `case`.

### KI-026
**`shipping_status` trả `not_shipped` cho đơn đã giao** · Low

- **Ở đâu:** [order.rb:104](../app/models/order.rb) `shipping_status` mở đầu bằng `return 'not_shipped' unless shipped?`. `shipped?` là predicate của enum, chỉ đúng khi `status == 'shipped'`. Vì vậy đơn `delivered` thoát ra từ dòng này, trước khi tới phép kiểm tra `delivered?`.
- **Tái hiện:** `Order.new(status: 'delivered').shipping_status` trả `"not_shipped"`. Chỉ `shipped` cho ra `in_transit`, còn mọi trạng thái khác đều ra `not_shipped`.
- **Ảnh hưởng:** trường `shipping_status` trong response order ([order_serializer_service.rb:24](../app/services/orders/order_serializer_service.rb)) và trong `GET /orders/:id/tracking` ([orders_controller.rb:108](../app/controllers/api/v1/orders/orders_controller.rb)) báo đơn đã giao là chưa gửi. Trường `status` trả về cùng lúc vẫn đúng.
- **Hướng sửa:** kiểm tra `delivered?` trước. Thêm unit test cho cả 5 trạng thái.

### KI-027
**Confirm đơn kiểm tra lại phần tồn kho mà chính đơn đó đã giữ** · Medium

- **Ở đâu (trước #53):** [order_confirmation_service.rb:72](../app/services/orders/order_confirmation_service.rb) `check_item_availability`. Hàm này so sánh `product.stock_quantity` với `item.quantity`. Nhưng tồn kho đã bị trừ từ lúc tạo đơn, trong `with_lock` ([order_creation_service.rb](../app/services/orders/order_creation_service.rb)), nên phần của chính đơn bị tính hai lần.
- **Hệ quả:**
  - Đơn chỉ confirm được khi tồn kho còn lại ≥ số lượng đặt, tức tồn kho ban đầu phải ≥ 2 lần số lượng.
  - Đơn mua sản phẩm cuối cùng (kho 1 → 0) báo `Some items are no longer available`, và **không bao giờ confirm được**.
  - Với item có variant, hàm còn kiểm tra kho của product thay vì kho của variant.
- **Tái hiện:** tạo đơn mua đúng số còn trong kho, rồi admin gọi `POST /orders/:id/confirm`. Phát hiện khi viết spec luồng đơn hàng cho việc 0.6 của roadmap.
- **Hướng sửa:** lúc confirm chỉ cần kiểm tra sản phẩm còn tồn tại, vì tồn kho đã được giữ khi tạo đơn.
- **Đã sửa:** #53. Lúc confirm, service chỉ kiểm tra sản phẩm còn tồn tại. Mỗi luồng trong [order_lifecycle_spec.rb](../spec/requests/api/v1/order_lifecycle_spec.rb) đều mua đúng sản phẩm cuối cùng trong kho.

### KI-028
**CI: spec Elasticsearch thỉnh thoảng fail với "index already exists"** · Low

- **Ở đâu:** [elasticsearch_search_spec.rb](../spec/services/products/elasticsearch_search_spec.rb) gọi `Product.reindex` trong `before`. [searchkick.rb](../config/initializers/searchkick.rb) đặt `request_timeout: 2` và `retry_on_failure: 1`.
- **Vì sao:** Elasticsearch trên CI chỉ có 512 MB heap, nên lệnh tạo index đôi khi chạy quá 2 giây. Client hết thời gian chờ và gửi lại đúng lệnh đó, trong khi lần đầu thực ra đã tạo xong, nên ES trả `resource_already_exists_exception`.
- **Đã gặp:** job `test (mysql)` của #54, một PR chỉ sửa docs. Chạy lại job thì xanh.
- **Tạm thời:** chạy lại job bị fail.
- **Hướng sửa:** trong môi trường test, tăng `request_timeout` và tắt retry cho các lệnh không idempotent như tạo index.

### KI-029
**"Logout mọi phiên" bỏ sót token cấp trong cùng giây với lúc logout** · Low

- **Ở đâu:** [cache_service.rb](../app/services/auth/jwt/cache_service.rb) `set_user_logout_timestamp` lưu `Time.current.to_i`. [decode_service.rb](../app/services/auth/jwt/decode_service.rb) chỉ từ chối token khi `iat < logout_timestamp`. Cả hai đều chính xác tới giây.
- **Hệ quả:** token của phiên khác được cấp trong cùng giây với lúc logout vẫn dùng được. Token của chính phiên logout thì đã nằm trong blacklist DB từ #55.
- **Vì sao chưa đổi thành `<=`:** nếu đổi, người dùng logout rồi login lại ngay trong cùng giây sẽ bị từ chối token mới.
- **Hướng sửa:** thêm `token_version` cho từng user trong DB và đưa nó vào claim của token. Logout chỉ cần tăng version, không phụ thuộc Redis hay độ chính xác của đồng hồ.
