# Bóng đèn gợi ý 3D

- Nguồn: [Microsoft Fluent Emoji — Light bulb 3D](https://github.com/microsoft/fluentui-emoji/blob/main/assets/Light%20bulb/3D/light_bulb_3d.png).
- Giấy phép: [MIT](https://github.com/microsoft/fluentui-emoji/blob/main/LICENSE), bản sao tại `assets/images/fluent_light_bulb_LICENSE.txt`.
- Asset: `assets/images/fluent_light_bulb_3d.png`, ảnh PNG nền trong suốt, không chỉnh sửa.
- Game điền từ hiển thị icon 30 px trong vùng chạm 44 px, bên phải dòng đồ vật và số ký tự.
- Mỗi đồ vật mở gợi ý lần lượt: nghĩa tiếng Việt → phiên âm → từ tiếng Anh. Các mức trước vẫn hiển thị; lần thứ ba không tự điền đáp án. Mức gợi ý được lưu trong `hint_levels` của bản nháp hiện có.
- Khung gợi ý dùng viền đậm, góc bo và bóng dưới/phải của app. Nội dung tự ẩn sau 5 giây kể từ khi tải xong; bấm lại sau mức 3 để xem lại trong 5 giây. Mỗi đồ vật có bộ đếm riêng. Mở lại bản nháp giữ mức đã dùng nhưng không tự hiện gợi ý.
- Nghĩa/phiên âm đọc từ Library cùng tài khoản, ưu tiên bản sửa mới nhất và kiểm tra từ khớp với đáp án của phiên học. Thiếu dữ liệu thì hiển thị thông báo thiếu; không tạo bản dịch hay phiên âm giả.
