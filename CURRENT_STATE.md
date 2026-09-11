# 1. ĐANG Ở ĐÂU

- Branch `AI-scan`, HEAD `17742d7`, đã đồng bộ hoàn toàn với `origin/AI-scan` (ahead 0/behind 0).
- Commit GitHub adaptive label overlay tasks 3–13b đã được fast-forward vào local; solver production hiện dùng `PlacedLabel`/`LabelPlacementSolver` trong `features/vocab_scan`.
- Pipeline progressive refinement/GrabCut local đã được gỡ theo quyết định sản phẩm; AI Scan tiếp tục dùng Stage 1 Gemini, bbox và adaptive label solver.
- Repo khai báo app `0.1.0`; không có artefact phát hành để xác minh số version binary đang trên máy người dùng. Production Supabase chỉ có `gemini-vision-scan` v15 `ACTIVE`.
- Không thay đổi hiện tại nào đã deploy/release, nên app production đang dùng không bị ảnh hưởng.

# 2. NHỮNG GÌ ĐÃ XONG (code có, test pass, đã review)

- Adaptive label placement từ GitHub: candidate rings, angle ranking, forbidden zones, connector collision, content-aware label sizing và fallback tiers; đã merge vào HEAD và test pass.
- Sobel edge-map được giữ như thuật toán độc lập; hiện chưa được nối vào luồng production.

# 3. NHỮNG GÌ ĐANG DỞ DANG (code có nhưng chưa xong/chưa test được)

- Chưa có benchmark thiết bị thật cho chất lượng và độ trễ của Stage 1 + adaptive label solver sau khi gỡ refinement.

# 4. NHỮNG GÌ CHƯA BẮT ĐẦU

- Kiểm thử Stage 1 và label placement trên bộ ảnh thật, đặc biệt cảnh đông và ảnh có tỷ lệ cực đoan.

# 5. QUYẾT ĐỊNH ĐANG CHỜ TÔI (không phải agent tự quyết)

- Có nối Sobel edge-map vào production hay tiếp tục giữ bbox connector hiện tại.

# 6. RỦI RO/CẢNH BÁO CÒN TỒN TẠI (nếu có)

- Baseline production Stage 1 ở P95 `5.126 s` theo log / `5.273 s` theo client tại lần đo trước.
- Worktree lớn chưa commit, có 2 file migration legacy đang staged-delete và nhiều artefact untracked; cần review kỹ trước mọi commit.
