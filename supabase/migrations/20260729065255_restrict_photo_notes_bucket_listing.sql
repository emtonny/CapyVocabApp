-- Bucket "photo_notes" đã public=true nên Supabase Storage tự phục vụ
-- object qua URL trực tiếp mà KHÔNG cần policy SELECT trên storage.objects.
-- Policy "Public Access Photo Notes" hiện tại cho phép SELECT không giới hạn,
-- vô tình cho phép liệt kê (list) toàn bộ file trong bucket. Xoá nó đi —
-- việc xem ảnh qua URL công khai vẫn hoạt động bình thường vì bucket là public.
drop policy if exists "Public Access Photo Notes" on storage.objects;;
