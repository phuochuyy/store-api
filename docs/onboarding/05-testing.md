# 05 · Testing

> Cập nhật theo commit: `1286f04` · Kết quả gần nhất: 684 examples, 0 failures, 5 pending (Elasticsearch), trên cả PostgreSQL và MySQL

Mọi file trong `spec/` đều được git theo dõi. Trước #47, spec và factory mới bị `.gitignore` ẩn mà không có cảnh báo nào ([KI-020](../known-issues.md#ki-020)). Giờ `bin/check-gitignore` chạy trong CI và trong `bin/ci` để chặn lỗi này quay lại.

## Công cụ
- RSpec, FactoryBot, shoulda-matchers, database_cleaner.
- rswag-specs để viết contract test theo OpenAPI.
- SimpleCov để đo coverage, chỉ chạy khi đặt `COVERAGE=true`.
- Helper ở [spec/support/](../../spec/support/):
  - `auth_headers(user)` sinh header `Authorization: Bearer …` ([jwt_helper.rb](../../spec/support/jwt_helper.rb)).
  - `redis_helper.rb` hỗ trợ test có dùng Redis.

## Lệnh hay dùng
```bash
bundle exec rspec                                   # toàn bộ, chạy trên PostgreSQL
bundle exec rspec spec/models/order_spec.rb:42      # một test theo dòng
COVERAGE=true bundle exec rspec                     # chạy kèm coverage (giống CI), xem coverage/index.html
DB_ADAPTER=trilogy DATABASE_PORT=3307 bundle exec rspec   # chạy trên MySQL, cần profile mysql
ELASTICSEARCH_URL=http://localhost:9200 bundle exec rspec spec/services/products/elasticsearch_search_spec.rb
```

## Bố cục và độ phủ

| Thư mục | File | Examples (ước tính) | Nội dung |
|---|---|---|---|
| `spec/controllers/` | 6 | 229 | auth, orders, payments; các concern authentication và authorization; kiểm tra kế thừa của controller v1 |
| `spec/models/` | 5 | 207 | order, payment, product, user, stock_concurrency |
| `spec/services/` | 8 | 151 | `auth/*`, `auth/jwt/*`, text search, Elasticsearch search |
| `spec/requests/` | 9 | 97 | rswag cho carts, orders, order items, payments, product variants, addresses, returns; luồng đơn hàng đầu cuối (order_lifecycle); error_handling |

- **Coverage gần nhất:** 46,90% số dòng và 30,00% số nhánh. Trước giai đoạn 0 là 37,42% và 25,81%.
- **Ngưỡng tối thiểu:** 37% số dòng, cấu hình trong [spec_helper.rb](../../spec/spec_helper.rb). Đây là cơ chế ratchet: mỗi khi coverage tăng thì nâng ngưỡng lên theo, không bao giờ hạ xuống. **Ngưỡng chưa được nâng theo** mức 47% hiện tại; nên nâng lên khoảng 45%.

**Hoàn toàn chưa có test:**
- **Controller:** brands, categories, products, discounts, promotions, shipping, tax, users.
- **Model:** 30 trên 33 model, trong đó có Payment, ReturnRequest, Discount, Coupon, Promotion, StockAlert.
- **Service:** tất cả service của Orders, Payments, Discounts, Returns, StockAlerts, Carts, Shipping, Tax và Users. Một phần được phủ gián tiếp qua controller spec và request spec.

Phần lớn lỗi trong [known-issues.md](../known-issues.md) nằm đúng ở những vùng chưa có test này.

## Viết request spec theo kiểu contract (khuyến nghị cho mọi endpoint mới)
Mẫu tham khảo:
- [carts_spec.rb](../../spec/requests/api/v1/carts_spec.rb): mẫu cơ bản.
- [returns_spec.rb](../../spec/requests/api/v1/returns_spec.rb): kiểm tra **ba vai trò** (chủ sở hữu, customer khác, admin) và khẳng định dữ liệu không đổi khi bị 403/404.
- [product_variants_spec.rb](../../spec/requests/api/v1/product_variants_spec.rb): response có `data` là mảng hoặc là một object.

```ruby
require 'swagger_helper'

RSpec.describe 'Brands API', type: :request do
  extend ContractSchemas
  let(:admin) { create(:user, :admin) }
  let(:Authorization) { auth_headers(admin)['Authorization'] }

  path '/api/v1/brands' do
    post 'Create brand' do
      tags 'Brands'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      parameter name: :body, in: :body, schema: { type: :object }

      response '201', 'created' do
        let(:body) { { brand: { name: 'Nokia' } } }
        schema envelope({ brand: ref('Brand') })   # schema phải có trong swagger/v1/components/schemas.yaml
        run_test!
      end

      response '403', 'customer forbidden' do
        let(:Authorization) { auth_headers(create(:user))['Authorization'] }
        let(:body) { { brand: { name: 'Nokia' } } }
        schema ref('ErrorResponse')
        run_test!
      end
    end
  end
end
```

**Mỗi endpoint cần tối thiểu các case sau:**
- 2xx khi thành công.
- 401 khi không có token.
- 403 khi sai vai trò, **và** 403 hoặc 404 khi truy cập tài nguyên của người khác (IDOR, xem [KI-004](../known-issues.md#ki-004)).
- 422 khi input sai.

## Spec cho tình huống đồng thời
[stock_concurrency_spec.rb](../../spec/models/stock_concurrency_spec.rb) là mẫu để kiểm tra `with_lock` bằng nhiều thread. Dùng cùng cách này cho bộ đếm lượt dùng discount ([KI-010](../known-issues.md#ki-010)) và cho thao tác hủy đơn hai lần.
