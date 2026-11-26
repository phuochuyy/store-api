# So sánh hiện trạng với target stack

> Cập nhật theo commit: `2ba3302`

**Target stack** là bộ công nghệ của một vị trí Rails backend mà dự án này hướng tới:
- **Hạ tầng:** AWS/GCP, Aurora MySQL, Elasticsearch, DynamoDB
- **CI/CD:** CircleCI, CodeBuild, GitHub Actions
- **IaC và cấu hình:** Terraform, Packer, Ansible
- **Monitoring:** Datadog, Bugsnag
- **Khác:** Swagger, Docker/Kubernetes, và kinh nghiệm refactor monolith sang microservices

**Ràng buộc hiện tại:** chưa dùng cloud. Mọi hạng mục phải chạy được ở local với chi phí 0đ và để lại bằng chứng: code, CI xanh, tài liệu.

## Bảng so sánh

| Hạng mục target | Hiện trạng | Khoảng trống | Thay thế ở local |
|---|---|---|---|
| **Rails thiết kế và triển khai** | Rails 8.1, nhiều tầng rõ ràng | Giai đoạn 0 xong (#46–#62): lỗi phân quyền, IDOR, state machine đơn hàng, logout trên MySQL, các cổng thanh toán và promotion. Không còn lỗi Critical hay High nào đang mở | — |
| **API design và tài liệu (Swagger)** | OpenAPI viết tay, 3 contract spec | YAML và JSON lệch nhau, phần lớn endpoint chưa có contract test ([KI-015](../known-issues.md#ki-015)) | rswag, CI kiểm tra drift |
| **Aurora MySQL** | Đã chạy MySQL 8.4 qua Trilogy, CI test cả hai DB | Lỗi token dài hơn VARCHAR(255) đã sửa (#55, [KI-006](../known-issues.md#ki-006)). Dev vẫn mặc định PostgreSQL | MySQL 8.4 trong compose (cùng dòng với Aurora MySQL 3) |
| **Elasticsearch** | searchkick, có fallback về SQL, reindex qua alias | Chỉ áp dụng cho Product. Chưa có analyzer tiếng Việt và facet | ES 9.5 trong compose |
| **DynamoDB** | Không có | Toàn bộ | DynamoDB Local hoặc LocalStack |
| **Microservices** | Monolith một DB, coupling qua callback và transaction | Chưa có ranh giới module, chưa có domain event | packwerk, outbox, message broker trong compose |
| **Docker** | Dockerfile dev, compose cho dev và prod | Chưa có image production (multi-stage, non-root) và worker Sidekiq. Prod compose đã chạy được từ #66 ([KI-013](../known-issues.md#ki-013)) | Docker |
| **Kubernetes** | Không có | Toàn bộ | kind hoặc minikube, Helm |
| **CI/CD** | GitHub Actions: test matrix, lint, security, build image | Chưa có bước CD, chưa push image | GitHub Actions và GHCR (miễn phí cho repo public). CircleCI có gói free nếu cần so sánh |
| **Terraform** | Không có | Toàn bộ | Terraform với provider AWS trỏ vào LocalStack |
| **Packer** | Không có | Toàn bộ | Packer với builder `docker` |
| **Ansible** | Không có | Toàn bộ | Ansible provision máy ảo Multipass hoặc Vagrant |
| **Datadog (APM, metrics, log)** | Log JSON (lograge), có request_id | Chưa có metrics và tracing | OpenTelemetry → Jaeger/Tempo, Prometheus + Grafana (yabeda). Datadog có trial nếu muốn demo |
| **Bugsnag (error tracking)** | Sentry SDK có, lọc PII ở mọi độ sâu (#56, [KI-009](../known-issues.md#ki-009)) | Chưa có môi trường chạy thử | GlitchTip tự host, tương thích Sentry SDK |
| **Phát hiện vấn đề từ log** | Có request_id, user_id trong log | Chưa có nơi tập trung log | Loki + Grafana |
| **Đo hiệu quả để cải thiện chất lượng** | Coverage 61,4% số dòng, ngưỡng ratchet 60% số dòng và 34% số nhánh | Chưa có SLO, chưa đo latency | k6 load test + dashboard |
| **Kinh nghiệm OSS và viết bài ra bên ngoài** | — | — | Blog viết từ các giai đoạn của roadmap |

## Gợi ý chọn middleware (để lập luận khi phỏng vấn)
- **Message broker cho domain event:**
  - Bắt đầu bằng **transactional outbox + Sidekiq**, vì dự án đã có Redis và Sidekiq.
  - Khi cần nhiều consumer hoặc replay event, chuyển sang **RabbitMQ** hoặc **Redis Streams**.
  - Chỉ cân nhắc Kafka khi throughput lớn. Với quy mô này Kafka là quá mức cần thiết.
- **Dùng DynamoDB cho gì:** chọn dữ liệu truy cập theo key, có TTL, không cần JOIN.
  - Ứng viên tốt nhất là **JWT blacklist**: TTL tự xóa, bỏ được `JwtCleanupJob`. Bảng đã lưu `token_digest` (#55), nên có sẵn partition key.
  - Ứng viên thứ hai là **notification feed**: tra theo `user_id` và `created_at`.
  - **Không** đưa Order hay Payment sang DynamoDB, vì hai domain này cần transaction quan hệ.
