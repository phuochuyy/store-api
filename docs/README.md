# Tài liệu Store API

> Cập nhật theo commit: `b47d3cc` · Ngày: 2026-11-25

Đây là tài liệu nội bộ để hiểu dự án và định hướng phát triển. Cách cài đặt và chạy dự án nằm ở [README gốc](../README.md).

## Thứ tự nên đọc

| # | Tài liệu | Đọc khi |
|---|---|---|
| 1 | [onboarding/01-architecture.md](onboarding/01-architecture.md) | Ngày đầu: các tầng, vòng đời request, quy ước code, checklist thêm tính năng |
| 2 | [onboarding/02-domain-map.md](onboarding/02-domain-map.md) | Trước khi sửa nghiệp vụ: domain, state machine, coupling |
| 3 | [onboarding/03-data-model.md](onboarding/03-data-model.md) | Trước khi viết migration: ER, ràng buộc, tương thích MySQL |
| 4 | [onboarding/04-infra-and-ops.md](onboarding/04-infra-and-ops.md) | Khi chạy service, CI, log, search, Swagger |
| 5 | [onboarding/05-testing.md](onboarding/05-testing.md) | Trước khi viết test: mẫu contract spec, vùng chưa có test |
| 6 | [known-issues.md](known-issues.md) | Trước khi nhận việc: các lỗi đã xác minh, mã `KI-xxx` |
| 7 | [roadmap/target-stack-gap.md](roadmap/target-stack-gap.md) | So sánh hiện trạng với target stack |
| 8 | [roadmap/roadmap.md](roadmap/roadmap.md) | Kế hoạch theo giai đoạn, chạy hoàn toàn ở local |

## Tóm tắt nhanh
- **Dự án:** Rails 8.1 API-only, monolith một DB (PostgreSQL mặc định, MySQL qua Trilogy). Dùng Redis, Sidekiq, JWT, và Elasticsearch (tùy chọn).
- **Các tầng:** controller → validator → policy → service → serializer. Response luôn theo khung `{ success, data, message }`.
- **Sức khỏe hiện tại:**
  - 759 test pass trên cả PostgreSQL và MySQL. Coverage là 61,4% số dòng (đo giống CI), ngưỡng ratchet đặt ở 58%.
  - **36 lỗi đã ghi nhận, 25 đã sửa** (#46–#70). Không còn lỗi Critical, High hay Medium nào đang mở; còn 11 lỗi Low, xem [known-issues.md](known-issues.md).
- **Hướng đi:** sửa lỗi → đồng nhất code → tương thích Aurora → observability → modular monolith → microservice đầu tiên (Notification) → DynamoDB → K8s và IaC trên local.

## Quy ước giữ tài liệu không bị cũ
1. **Mỗi kiến thức chỉ ghi ở một chỗ.**
   - Lỗi chỉ được mô tả trong `known-issues.md`. Nơi khác trỏ tới `KI-xxx`.
   - Chi tiết domain chỉ nằm ở `02-domain-map.md`.
2. **Trỏ tới file, không dán code.** Dùng link tương đối, kèm số dòng khi cần. Số dòng có thể lệch theo thời gian; tên method thì ổn định hơn.
3. **Chỉ ghi những gì không đọc được trực tiếp từ code:** lý do, rủi ro, coupling, lỗi, quyết định. Cột hay method cụ thể thì đọc `schema.rb` hoặc code.
4. **Dòng `Cập nhật theo commit` ở đầu mỗi file:** khi sửa nội dung thì cập nhật hash. Xem code đã đổi bao nhiêu kể từ lần cập nhật đó:
   ```bash
   git diff --stat <hash>..HEAD -- app config db
   ```
5. **Sửa lỗi xong thì cập nhật dòng `KI-xxx`** thành `fixed (#PR)`. Không xóa dòng, để giữ lịch sử.
6. Quyết định kiến trúc lớn (khi tới giai đoạn 4) ghi thành ADR trong `docs/adr/NNNN-tieu-de.md`.
