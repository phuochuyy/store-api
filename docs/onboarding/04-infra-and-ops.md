# 04 · Hạ tầng và vận hành

> Cập nhật theo commit: `3ed8915`

## Môi trường local

| Thành phần | Phiên bản | Cách chạy | Cổng |
|---|---|---|---|
| Ruby | 3.4.5 ([.ruby-version](../../.ruby-version)), Bundler 2.7.1 | Cài trên máy qua mise/rbenv | — |
| PostgreSQL | 15 | `docker compose up -d` (service `db`) | 5433 |
| Redis | 7 | `docker compose up -d` (service `redis`) | 6379 |
| MySQL | 8.4, tùy chọn | `docker compose --profile mysql up -d mysql` | 3307 |
| Elasticsearch | 9.5.5, tùy chọn | `docker compose --profile search up -d elasticsearch` | 9200 |

Rails chạy **trên máy**, chỉ các dịch vụ phụ trợ chạy trong container:
```bash
bin/rails db:prepare
bin/rails server
bundle exec sidekiq
```

## Biến môi trường quan trọng

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `DB_ADAPTER` | `postgresql` | Đặt `trilogy` để dùng MySQL |
| `DATABASE_HOST` / `DATABASE_PORT` | `127.0.0.1` / 5433 (PG) hoặc 3307 (MySQL) | |
| `REDIS_URL` | `redis://localhost:6379/0` | Cache, Sidekiq, JWT cache |
| `JWT_SECRET_KEY` | dùng `secret_key_base` | Khóa ký JWT |
| `SEARCH_BACKEND` | `sql` | Đặt `elasticsearch` để bật searchkick callbacks và tìm kiếm bằng ES |
| `ELASTICSEARCH_URL` | — | |
| `COVERAGE` | — | Đặt `true` để bật SimpleCov (CI có bật) |
| `SENTRY_DSN`, `APP_VERSION` | — | Chỉ có tác dụng ở production và staging |

- **Figaro** đã được cài nhưng hầu như không dùng. Không cần tạo `config/application.yml`.
- `.env.example` và `application.yml.example` có giá trị DB **không khớp** với `database.yml`. Đừng chép nguyên các file này.

## CI (GitHub Actions)

[.github/workflows/ci.yml](../../.github/workflows/ci.yml) chạy cho mọi PR và mỗi lần push lên `main`.

| Job | Nội dung |
|---|---|
| `test` | Matrix `postgresql` × `mysql`, `fail-fast: false`. Mỗi lượt chạy đều khởi động đủ PG 15, MySQL 8.4, Redis 7 và ES 9.5.5. Các bước: `db:schema:load` → `rspec` với `COVERAGE=true` → upload artifact coverage |
| `lint` | `bin/rubocop -f github` |
| `security` | `brakeman --exit-on-warn` và `bundler-audit check --update` |
| `docker` | Chạy sau 3 job trên. Build image (buildx, cache GHA) rồi smoke test bằng `bin/rails --version`. Không push image |

- Dependabot cập nhật gem và GitHub Actions hằng ngày.
- **Chạy giống CI ở máy local:** `bin/ci` (dùng `ActiveSupport::ContinuousIntegration`, cấu hình trong [config/ci.rb](../../config/ci.rb)).

## Container
- **[Dockerfile](../../Dockerfile)** là bản cho **development**:
  - Chỉ có một stage, dùng `ruby:3.4.5-slim`.
  - `RAILS_ENV=development`, chạy bằng root.
  - Chỉ có client của PostgreSQL. jemalloc được cấu hình trong entrypoint nhưng không được cài.
- **[bin/docker-entrypoint](../../bin/docker-entrypoint)** chỉ hỗ trợ PostgreSQL: chờ `psql` sẵn sàng rồi chạy `db:prepare`.
- **[docker-compose.prod.yml](../../docker-compose.prod.yml)** gồm `db`, `redis` (có password) và `web`.
  - Thiếu worker Sidekiq và Elasticsearch.
  - **Không kết nối được DB** ([KI-013](../known-issues.md#ki-013)).
- **Makefile:**
  - [Makefile](../../Makefile) dùng cho thao tác hằng ngày.
  - [Makefile.docker](../../Makefile.docker) phải gọi bằng `make -f Makefile.docker …`.
  - `make docs` bị hỏng ([KI-019](../known-issues.md#ki-019)).
- Chưa có Kubernetes, Helm, Kamal, Terraform, Ansible hay Packer.

## Observability

| Hạng mục | Hiện trạng | File |
|---|---|---|
| Log | Lograge xuất JSON gồm `time`, `request_id`, `user_id`, `ip`, `user_agent`, bỏ qua request health check. Production ghi ra stdout, gắn tag `request_id`. Header `X-Request-ID` được mở qua CORS | [lograge.rb](../../config/initializers/lograge.rb) |
| Error tracking | Sentry, `traces_sample_rate` 0.1 ở production. **Không lọc PII** ([KI-009](../known-issues.md#ki-009)) | [sentry.rb](../../config/initializers/sentry.rb) |
| Health check | `/health` (OkComputer: database, redis, sidekiq, app, version) và `/api/v1/health` (tự viết) | [okcomputer.rb](../../config/initializers/okcomputer.rb) |
| Metrics / APM | **Chưa có** (không có StatsD, Prometheus, Datadog) | — |
| Sidekiq UI | Chưa mount | — |

## Rate limiting ([rack_attack.rb](../../config/initializers/rack_attack.rb))
- **Giới hạn:**
  - 60 request/phút mỗi IP (áp dụng cho mọi request).
  - Đăng nhập: 5 lần/20 giây theo IP và theo email.
  - Đăng ký: 3 lần/giờ. Reset mật khẩu: 5 lần/giờ.
  - `/api/` 100 request/phút. Giới hạn này **không bao giờ chạm tới**, vì giới hạn 60/phút ở trên chặn trước.
- Lưu bộ đếm bằng Redis ở production, bằng memory ở các môi trường khác. Rack::Attack bị tắt khi chạy test.
- Khi bị chặn, trả 429 kèm body JSON và các header `X-RateLimit-*`.

## Tìm kiếm sản phẩm
- **Mặc định:** dùng SQL `LIKE`/`ILIKE` qua [Search::Like](../../app/services/search/like.rb).
- **Khi `SEARCH_BACKEND=elasticsearch`:**
  - Dùng searchkick ([product.rb:43](../../app/models/product.rb)). Boost theo `name^5`, `brand_name^3`, `category_name^2`, `description`.
  - Có tolerance cho lỗi gõ.
  - Index được cập nhật bất đồng bộ qua Active Job. Đổi tên brand hoặc category sẽ reindex các sản phẩm liên quan.
- **Khi ES lỗi hoặc chậm hơn 2 giây:** ghi log `[search] Elasticsearch unavailable` rồi quay về tìm bằng SQL.
- **Reindex không downtime:** `bin/rails searchkick:reindex CLASS=Product`.

## Tài liệu API (Swagger)
- **Nguồn hiện tại là YAML viết tay:** [swagger/v1/swagger.yaml](../../swagger/v1/swagger.yaml), cùng `paths/*.yaml` và `components/*.yaml`.
- **File được phục vụ:** `bin/rails swagger:merge` sinh ra `swagger.json`. Trang `/api-docs` ([api_docs_controller.rb](../../app/controllers/api_docs_controller.rb), swagger-ui 5.9.0 tải từ unpkg) hiển thị file này.
- **Contract test:** [spec/swagger_helper.rb](../../spec/swagger_helper.rb) kiểm tra response theo `components/schemas.yaml`. Không chạy `rswag:specs:swaggerize`.
- **YAML và JSON đang lệch nhau** ([KI-015](../known-issues.md#ki-015)).

## Job nền (Sidekiq)
- Active Job dùng adapter Sidekiq ở mọi môi trường.
- Lịch cron nằm ở [config/schedule.yml](../../config/schedule.yml), được sidekiq-cron nạp vào.
- Danh sách job: `JwtCleanupJob` (02:00 mỗi ngày), `StockAlertNotificationJob` (enqueue khi có alert), và job reindex của searchkick.
