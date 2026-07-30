CAPY VOCAB - DATABASE MANAGEMENT
================================

Cấu trúc thư mục:
- migrations/: Chứa các file SQL migration tạo/sửa đổi bảng theo thời gian (ví dụ: 20260730_align_secure_schema.sql).
- schema/: Chứa bản snapshot tổng thể của toàn bộ database schema (supabase_schema_final_secure.sql).

Quy tắc làm việc với Database:
1. Khi có thay đổi DB mới, tạo file migration mới trong thư mục `migrations/` với prefix timestamp (YYYYMMDD_tên_thay_đổi.sql).
2. Cập nhật bản snapshot tổng thể trong `schema/supabase_schema_final_secure.sql` để phản ánh trạng thái mới nhất của Database.

