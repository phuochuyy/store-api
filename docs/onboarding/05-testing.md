# 05 · Testing

> Cập nhật theo commit: `3ed8915` · Kết quả gần nhất: 597 examples, 0 failures, 5 pending (Elasticsearch)

> ⚠️ **Đọc trước khi viết spec mới:** `.gitignore` đang bỏ qua mọi file `*_spec.rb` không có trong whitelist ([KI-020](../known-issues.md#ki-020)). Kiểm tra bằng `git check-ignore -v <file>`. Nếu file bị ignore, dùng `git add -f`.

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
| `spec/controllers/` | 5 | ~219 | auth, orders, payments; các concern authentication và authorization |
| `spec/models/` | 4 | ~201 | order, product, user, stock_concurrency |
| `spec/services/` | 8 | ~148 | `auth/*`, `auth/jwt/*`, text search, Elasticsearch search |
| `spec/requests/` | 4 | 26 `run_test!` | rswag cho carts, orders, payments; error_handling |

- **Coverage gần nhất:** 37,42% số dòng và 25,81% số nhánh.
- **Ngưỡng tối thiểu:** 37% số dòng, cấu hình trong [spec_helper.rb](../../spec/spec_helper.rb). Đây là cơ chế ratchet: mỗi khi coverage tăng thì nâng ngưỡng lên theo, không bao giờ hạ xuống.

**Hoàn toàn chưa có test:**
- **Controller:** brands, categories, products, variants, returns, discounts, promotions, shipping, tax, addresses, users.
- **Model:** 30 trên 33 model, trong đó có Payment, ReturnRequest, Discount, Coupon, Promotion, StockAlert.
- **Service:** tất cả service của Orders, Payments, Discounts, Returns, StockAlerts, Carts, Shipping, Tax và Users. Một phần được phủ gián tiếp qua controller spec và request spec.

Phần lớn lỗi trong [known-issues.md](../known-issues.md) nằm đúng ở những vùng chưa có test này.

## Viết request spec theo kiểu contract (khuyến nghị cho mọi endpoint mới)
Mẫu tham khảo: [spec/requests/api/v1/carts_spec.rb](../../spec/requests/api/v1/carts_spec.rb).

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
