# KẾ HOẠCH CHỨC NĂNG VÀ LUỒNG UX — TRANG CHỦ (HOME)

## 0. Phạm vi và trạng thái tài liệu

Tài liệu này là nguồn thống nhất cho **giao diện và luồng sử dụng của Home** trên web và ứng dụng điện thoại. Nội dung mô tả những gì người dùng nhìn thấy, thao tác và nhận được; chưa đặc tả cơ sở dữ liệu, đồng bộ Supabase hay cách viết backend.

Trạng thái hiện tại: **H2A–H4 và H5A–H5D đã hoàn thành. Backend H5 được xác minh lại trên exact Staging ngày 06/10/2026; full regression và Web/Android release build đều pass. Smoke Android vật lý online → offline → reconnect gần nhất pass ngày 04/10/2026; lần nghiệm thu 06/10 chưa lặp lại vì ADB không thấy thiết bị. Production chưa được thay đổi**.

Các tên hàm, biến, CSS, SVG hoặc Web Speech API trong bản demo cũ chỉ là tham khảo. Bản Flutter/web có thể triển khai khác nhưng phải giữ đúng hành vi UX trong tài liệu này.

### 0.1. Thuật ngữ thống nhất

- **Xu Yuzu:** đơn vị tiền tệ duy nhất trong ứng dụng.
- **Số dư Yuzu:** lượng xu người dùng có thể dùng để mua vật phẩm.
- **Yuzu tuần:** phần xu hợp lệ dùng để xếp hạng trong tuần; đây không phải một loại tiền khác.
- **Yuzu chờ đồng bộ:** phần thưởng đã hoàn thành khi offline nhưng chưa được hệ thống xác nhận; hiển thị riêng và chưa được phép chi tiêu.
- **Photo Note:** bộ ảnh và từ vựng của một ngày. Mỗi ngày tương ứng với một node trên bản đồ học tập.
- **Lần hoàn thành đầu:** lần đầu người dùng hoàn thành 100% bài của Photo Note.
- **Chơi lại:** lần chơi sau khi Photo Note đã từng hoàn thành 100%.

### 0.2. Công thức xu và xếp hạng

Ứng dụng chỉ dùng một đơn vị là xu Yuzu, nhưng hiển thị hai số liệu phục vụ hai mục đích khác nhau:

```text
Số dư Yuzu
= xu nhiệm vụ
+ xu thắng cược
+ xu thưởng chơi lại hợp lệ
- xu thua cược
- xu mua vật phẩm

Yuzu tuần
= xu nhiệm vụ hợp lệ trong tuần
+ xu thắng cược
- xu thua cược
```

Quy tắc:

- Mua vật phẩm chỉ làm giảm **Số dư Yuzu**, không làm tụt **Yuzu tuần** đã ghi nhận.
- Chơi lại chỉ có thể cộng vào **Số dư Yuzu**, không cộng vào **Yuzu tuần**.
- Bảng xếp hạng sắp xếp theo **Yuzu tuần**, không theo số dư còn lại trong ví.
- Không cộng xu theo từng câu đúng. Xu chỉ được chốt khi bài đủ điều kiện hoàn thành 100%.

### 0.3. Mức thưởng nhiệm vụ ngày đã chốt

Người dùng chọn số từ tối thiểu mỗi ngày trong onboarding. Mốc đã chọn áp dụng từ ngày tiếp theo nếu người dùng thay đổi trong Cài đặt; không được hạ mục tiêu của ngày đang diễn ra.

| Số từ hợp lệ trong ngày | Thưởng đúng hạn | Thưởng hoàn thành muộn |
|---|---:|---:|
| Từ 100% đến dưới 150% mục tiêu | 100 Yuzu | 67 Yuzu |
| Từ 150% đến dưới 200% mục tiêu | 130 Yuzu | 87 Yuzu |
| Từ 200% mục tiêu trở lên | 150 Yuzu | 100 Yuzu |
| Dưới mục tiêu hoặc không hoàn thành 100% bài | 0 Yuzu | 0 Yuzu |

Ví dụ người dùng đặt mục tiêu 10 từ: 10–14 từ nhận 100 Yuzu; 15–19 từ nhận 130 Yuzu; từ 20 từ trở lên nhận 150 Yuzu. Khi hoàn thành muộn, phần thưởng bị giảm một phần ba và làm tròn đến số nguyên gần nhất như bảng trên.

Không hoàn thành nhiệm vụ không làm trừ số dư Yuzu đã kiếm từ trước. Hình phạt đã chốt là nhận 0 Yuzu cho nhiệm vụ đó và bị ngắt chuỗi.

Khoảng hoàn thành muộn đã chốt là **24 giờ**, dùng đúng `next_day_ends_at`
đã đóng băng cùng nhiệm vụ. Sau mốc này, kết quả vẫn được lưu để ôn nhưng không
phát sinh thưởng nhiệm vụ hoặc thưởng chơi lại.

---

## 1. Thanh thông tin phía trên

### Mục đích

Cho người dùng nhìn nhanh số dư và các thông báo cần xử lý.

### Nội dung và tương tác

- Badge ví hiển thị **Số dư Yuzu đã xác nhận**.
- Nếu có phần thưởng offline chưa đồng bộ, hiển thị thêm dòng hoặc trạng thái `Đang chờ đồng bộ: X Yuzu`; không cộng số này vào số dư có thể chi tiêu.
- Badge thông báo hiển thị số thông báo chưa đọc và mở danh sách thông báo khi bấm.
- Nút Cài đặt mở màn Cài đặt.
- Sau khi số dư thay đổi do nhiệm vụ, cược hoặc mua vật phẩm, mọi nơi đang hiển thị ví phải cập nhật nhất quán.

## 2. Khu vực chào mừng và linh vật

### Mục đích

Hiển thị lời chào cá nhân hóa và linh vật với trang phục hiện tại của người dùng.

### Nội dung và tương tác

- Hiển thị lời chào theo tên người dùng.
- Linh vật dùng đúng trang phục/phụ kiện đã chọn trong kho đồ.
- Khi người dùng đổi đồ, Home phải hiển thị cấu hình mới sau khi quay lại mà không yêu cầu đăng nhập lại.

## 3. Chuỗi ngày học liên tiếp

### Quy tắc đã chốt

- Không còn hành động bấm nút để tự nhận chuỗi hoặc nhận xu riêng.
- Một ngày chỉ được tính chuỗi khi người dùng:
  1. Tạo đủ số từ hợp lệ theo mục tiêu ngày.
  2. Hoàn thành 100% bài học của Photo Note ngày đó.
- Hoàn thành online: hiển thị chuỗi mới ngay sau khi kết quả được xác nhận.
- Hoàn thành offline: giao diện hiển thị `Đã hoàn thành — chờ đồng bộ`, đồng thời thể hiện chuỗi cục bộ để người dùng biết kết quả đã được lưu trên máy.
- Thoát giữa bài không làm mất chuỗi ngay. Nếu đến hạn mà bài vẫn chưa hoàn thành 100%, ngày đó không được nối chuỗi và chuỗi bị ngắt.
- Hoàn thành muộn trong cửa sổ 24 giờ chỉ nhận mức thưởng muộn và **không phục
  hồi chuỗi**.

## 4. Bảng xếp hạng bạn bè rút gọn

### Mục đích

Hiển thị ba người có Yuzu tuần cao nhất trong phạm vi bạn bè.

### Nội dung và tương tác

- Mỗi dòng hiển thị hạng, ảnh đại diện, tên và Yuzu tuần.
- Danh sách được sắp giảm dần theo Yuzu tuần.
- Bấm vào thẻ mở bảng xếp hạng đầy đủ trong khu vực Bạn bè.
- Khi offline, hiển thị dữ liệu gần nhất trên máy kèm nhãn `Cập nhật lần cuối ...`.
- Yuzu đang chờ đồng bộ không làm thay đổi thứ hạng cho đến khi được hệ thống xác nhận.
- Khi kết nối trở lại và đồng bộ thành công, điểm tuần và vị trí được làm mới.

## 5. Nhiệm vụ ngày

### 5.1. Một nhiệm vụ ngày gồm hai giai đoạn

1. **Tạo dữ liệu học:** chụp ảnh trong ngày và tạo đủ số từ hợp lệ theo mục tiêu đã chọn.
2. **Hoàn thành bài học:** chơi vòng lặp ôn tập cho đến khi toàn bộ từ của Photo Note được trả lời đúng.

Chỉ khi hoàn thành cả hai giai đoạn, nhiệm vụ mới đạt 100% và được xét thưởng.

### 5.2. Thẻ tiến trình nhiệm vụ

Thẻ trên Home cần hiển thị:

- `Mục tiêu: N từ`.
- `Đã nhận diện: M từ hợp lệ`.
- `Còn thiếu: K từ` nếu chưa đạt mục tiêu.
- Tiến trình bài học `X/Y từ đã làm đúng` sau khi đã có dữ liệu chơi.
- Trạng thái: `Chưa đủ dữ liệu`, `Sẵn sàng học`, `Đang học`, `Chờ đồng bộ`, `Đã hoàn thành` hoặc `Đã quá hạn`.
- Phần thưởng dự kiến theo số từ hợp lệ hiện có: 100, 130 hoặc 150 Yuzu.

Nút chính thay đổi theo trạng thái:

- `Chụp thêm ảnh` khi chưa đủ dữ liệu.
- `Bắt đầu bài học` khi đã đủ dữ liệu và chưa có tiến trình.
- `Tiếp tục bài học X/Y` khi đã lưu tiến trình giữa chừng.
- `Đang chờ đồng bộ` khi hoàn thành offline.
- `Chơi lại` khi bài đã hoàn thành và đã được xác nhận.

### 5.3. Khi đã chụp ảnh nhưng chưa tạo đủ từ

- Chỉ từ vựng **hợp lệ và không trùng lặp** mới được tính vào mục tiêu.
- Giao diện giải thích rõ ảnh/từ không được tính vì: trùng lặp, ảnh mờ, không nhận diện được, sai ngôn ngữ đang học hoặc vẫn đang xử lý.
- Cho phép người dùng chụp thêm ảnh, chụp lại ảnh lỗi hoặc chọn ảnh được chụp trong chính ngày đó từ Thư viện.
- Không phạt người dùng khi ảnh vẫn đang xử lý hoặc lỗi do hệ thống. Chỉ đánh giá sau khi mọi ảnh đã có kết quả cuối cùng.
- Nếu hết hạn mà vẫn dưới mục tiêu, nhiệm vụ không hoàn thành, nhận 0 Yuzu và chuỗi bị ngắt.

### 5.4. Ranh giới ngày

- Một ngày được tính từ 00:00 đến trước 00:00 của ngày tiếp theo theo múi giờ tài khoản đã chọn.
- Hệ thống kiểm tra trạng thái nhiệm vụ vào 00:00.
- Ảnh chụp lúc 23:59 thuộc Photo Note của ngày vừa kết thúc, kể cả khi việc xử lý ảnh hoàn tất sau 00:00.
- Ảnh và từ của ngày trước không tự chuyển sang nhiệm vụ ngày mới.
- Thời điểm chụp là căn cứ gán ngày; việc đổi giờ thiết bị không được làm thay đổi Photo Note đã gán.

## 6. Bản đồ học tập

### 6.1. Cấu trúc bản đồ

- Mỗi node đại diện cho **một Photo Note của một ngày**.
- Node dùng ảnh và từ vựng đã tạo trong đúng ngày đó.
- Người dùng có thể xem theo tuần hoặc tháng và chọn khoảng thời gian.
- Khi mở Home, bản đồ tự đưa node hôm nay hoặc node đang học vào vùng nhìn thấy.

### 6.2. Trạng thái node

- `Chưa có dữ liệu`: ngày hiện tại chưa đủ từ; bấm vào sẽ dẫn tới luồng bổ sung ảnh.
- `Sẵn sàng`: đã đủ từ và có thể bắt đầu bài học.
- `Đang học`: có tiến trình chưa hoàn tất; bấm vào để tiếp tục.
- `Chờ đồng bộ`: đã hoàn thành offline nhưng kết quả chưa được xác nhận online.
- `Đã hoàn thành`: bài đã hoàn thành và kết quả đã được xác nhận.
- `Đã quá hạn`: bài ngày cũ không hoàn thành đúng quy định; vẫn có thể mở để ôn nhưng không nhận thưởng nhiệm vụ ngày.

Không dùng khóa tuyến tính khiến người dùng mất quyền ôn bài cũ. Node ngày mới chỉ có bài khi ngày đó đã tạo được dữ liệu từ ảnh.

### 6.3. Khi bấm node

- Node hôm nay chưa đủ dữ liệu: mở phần giải thích còn thiếu và hành động bổ sung ảnh.
- Node sẵn sàng/đang học: mở hoặc tiếp tục game.
- Node chờ đồng bộ: hiển thị kết quả cục bộ và trạng thái chờ; không tạo thêm một lần thưởng mới.
- Node đã hoàn thành/quá hạn: mở chế độ chơi lại hoặc ôn tập theo luật mục 8.

## 7. Luồng game học từ ảnh

Hai kiểu tương tác trong demo — sắp xếp từ theo ảnh và điền từ theo ảnh — có thể được giữ làm màn chơi. Cả hai phải dùng chung luật hoàn thành, lưu tiến trình và thưởng dưới đây.

### 7.1. Bắt đầu bài

1. Người dùng mở node ngày.
2. Màn game tải ảnh và toàn bộ từ hợp lệ của Photo Note đó.
3. Thanh đầu màn hình hiển thị tiến trình `X/Y`, nút thoát và trạng thái online/offline.
4. Nếu đã có tiến trình dở dang, người dùng tiếp tục từ phần còn lại thay vì bắt đầu lại.

### 7.2. Học đến khi đúng 100%

- Từ trả lời đúng được đánh dấu đã hoàn thành.
- Từ trả lời sai được đưa lại vào hàng đợi để người dùng làm lại.
- Không trừ mạng và không cho phép bỏ qua từ sai trong bài nhiệm vụ ngày.
- Bài tiếp tục lặp cho đến khi tất cả từ đều đúng.
- Khi hàng đợi còn lại bằng 0, bài tự chuyển sang màn hoàn thành 100%.
- Không cộng Yuzu theo từng từ đúng và không thưởng cho kết quả một phần.

### 7.3. Thoát, đóng ứng dụng và tiếp tục

- Khi người dùng thoát hoặc ứng dụng bị đóng, lưu số từ đã hoàn thành và danh sách còn lại.
- Hiển thị xác nhận: `Tiến trình đã được lưu. Nhiệm vụ chưa hoàn thành và chưa có thưởng.`
- Quay lại trước hạn sẽ thấy nút `Tiếp tục bài học X/Y`.
- Tiến trình giữa chừng chỉ giúp tiếp tục học; không được dùng để cộng Yuzu, Yuzu tuần hoặc chuỗi.
- Nếu quá thời hạn và quá cả khoảng hoàn thành muộn sau khi khoảng này được chốt, phiên dở dang chuyển thành ôn tập và không còn quyền nhận thưởng nhiệm vụ ngày.

### 7.4. Hoàn thành online

1. Người dùng làm đúng toàn bộ từ.
2. Hiển thị màn hoàn thành, số Yuzu nhận được và chuỗi mới.
3. Số dư Yuzu và Yuzu tuần được cập nhật theo luật thưởng lần đầu.
4. Node chuyển sang `Đã hoàn thành`.
5. Bảng xếp hạng được làm mới khi có dữ liệu mới.

### 7.5. Hoàn thành offline

1. Người dùng vẫn được chơi nếu dữ liệu Photo Note đã có trên máy.
2. Khi đạt 100%, giao diện xác nhận `Đã hoàn thành` và hiển thị chuỗi cục bộ.
3. Phần thưởng hiển thị là `Yuzu chờ đồng bộ`, chưa thể mua vật phẩm và chưa lên bảng xếp hạng.
4. Node chuyển sang `Chờ đồng bộ`.
5. Khi có mạng, ứng dụng gửi kết quả. Sau khi được xác nhận, Yuzu chuyển từ chờ sang số dư, Yuzu tuần và thứ hạng được cập nhật.
6. Nếu đồng bộ lỗi, giữ kết quả trên máy và hiển thị nút `Thử đồng bộ lại`; không bắt người dùng chơi lại.

## 8. Chơi lại và ôn tập offline

### 8.1. Luật chơi lại

- Lần hoàn thành đầu tiên, online hoặc offline, nhận đủ phần thưởng hợp lệ của nhiệm vụ ngày.
- Lần hoàn thành thứ hai của cùng Photo Note nhận **một phần ba phần thưởng lần đầu**, làm tròn xuống.
- Thưởng chơi lại chỉ cộng vào Số dư Yuzu, không cộng Yuzu tuần và không thay đổi chuỗi.
- Từ lần hoàn thành thứ ba trở đi là ôn tập: không nhận thêm Yuzu.
- Chơi lại offline vẫn được, nhưng phần thưởng một phần ba ở trạng thái chờ cho đến khi đồng bộ thành công.
- Mỗi Photo Note chỉ có tối đa một lần thưởng chơi lại để chống lạm phát.

Ví dụ: lần đầu nhận 100 Yuzu thì lần chơi lại có thưởng nhận 33 Yuzu; những lần sau nhận 0 Yuzu.

### 8.2. Ôn bài cũ khi offline

- Người dùng có thể mở các Photo Note đã tải về để ôn khi không có mạng.
- Không cần kết nối mạng để xem ảnh, nghe nội dung đã lưu hoặc chơi game ôn tập.
- Chỉ lần đầu và lần chơi lại có thưởng mới tạo kết quả chờ đồng bộ; các lượt ôn tập sau không tạo giao dịch xu.

### 8.3. Chế độ ảnh tự chọn trong demo cũ

- Ảnh dùng để hoàn thành nhiệm vụ ngày phải thuộc đúng ngày của Photo Note; không được lấy ảnh lịch sử để bù mục tiêu hôm nay.
- Người dùng có thể chọn ảnh lịch sử để tạo một phiên **luyện tập tự do**, nhưng phiên này không tác động nhiệm vụ ngày, chuỗi hoặc Yuzu tuần.
- Cơ chế `3 tim` trong demo cũ chỉ được cân nhắc cho luyện tập tự do. Nó không áp dụng cho bài nhiệm vụ ngày vì bài ngày yêu cầu lặp đến khi đúng 100%.
- Giao diện và luật thưởng riêng của luyện tập tự do cần được đối chiếu lại với demo trước khi triển khai; mặc định hiện tại là không thưởng để tránh tạo thêm nguồn xu chưa được duyệt.

## 9. Hạn mức xử lý ảnh

### Mục đích

Cho người dùng biết số lượt xử lý ảnh còn lại và tránh thao tác thất bại không rõ nguyên nhân.

### Luồng UX

- Home hiển thị số lượt còn lại trong ngày.
- Trước khi mở camera hoặc tải ảnh lên, kiểm tra khả năng thực hiện.
- Nếu hết lượt, giải thích rõ lý do và thời điểm có lượt mới; không trừ lượt khi thao tác chưa tạo được kết quả.
- Lỗi xử lý do hệ thống không được tính là lỗi nhiệm vụ của người dùng và không được tự động làm mất chuỗi.
- Hạn mức ngày được làm mới theo cùng ranh giới 00:00 của nhiệm vụ ngày.

## 10. Điều hướng toàn cục

- Thanh điều hướng dưới cùng mở Home, Thư viện, Pet Shop và Bạn bè.
- Nút Camera ở giữa mở luồng tạo Photo Note sau khi kiểm tra hạn mức.
- Bong bóng Chat mở cuộc trò chuyện giữa người dùng với bạn bè. Đây là chat người-với-người, không phải chatbot.
- Bong bóng Chat phải xuất hiện nhất quán trên web và ứng dụng ở những màn đã cho phép chat; trạng thái đăng nhập thay đổi thì làm mới phiên thay vì biến mất im lặng.

## 11. Ma trận hành vi UX

| Tình huống | Trạng thái hiển thị | Số dư Yuzu | Yuzu tuần | Chuỗi |
|---|---|---:|---:|---|
| Chưa đủ số từ khi còn thời gian | Chưa đủ dữ liệu | Không đổi | Không đổi | Chưa kết luận |
| Thoát giữa bài trước hạn | Đang học, có nút tiếp tục | Không đổi | Không đổi | Chưa kết luận |
| Hết hạn và chưa hoàn thành | Đã quá hạn | Không cộng | Không cộng | Bị ngắt |
| Hoàn thành lần đầu online đúng hạn | Đã hoàn thành | Cộng đủ | Cộng đủ | Ghi nhận ngay |
| Hoàn thành lần đầu offline đúng hạn | Chờ đồng bộ | Chờ xác nhận | Chưa cộng | Hiển thị đã ghi nhận cục bộ |
| Đồng bộ lần đầu thành công | Đã hoàn thành | Chuyển chờ sang khả dụng | Cộng điểm hợp lệ | Xác nhận trên hệ thống |
| Hoàn thành muộn trong thời gian cho phép | Đã hoàn thành muộn | Cộng mức đã giảm | Cộng mức đã giảm | Chờ quyết định phục hồi chuỗi |
| Chơi lại có thưởng lần đầu | Đã ôn tập | Cộng 1/3 | Không cộng | Không đổi |
| Chơi lại từ lần tiếp theo | Đã ôn tập | Không cộng | Không cộng | Không đổi |
| Mua vật phẩm | Ví cập nhật | Bị trừ | Không đổi | Không đổi |

## 12. Kế hoạch triển khai Home

Mỗi mốc chỉ chuyển sang `HOÀN THÀNH` khi đã chạy kiểm tra tương ứng trên cả web và ứng dụng điện thoại.

### H0 — Khóa hợp đồng UX và đối chiếu demo — `CHỜ THỰC HIỆN`

- Đối chiếu các màn Home/game hiện tại với tài liệu này.
- Gắn nhãn rõ phần demo nào được giữ, phần nào chỉ dùng làm tham khảo.
- Chốt thời lượng hoàn thành muộn và quy tắc phục hồi chuỗi khi hoàn thành muộn.
- Kết quả cần có: không còn hai cách hiểu khác nhau về xu, chuỗi, ngày hoặc chơi lại.

### H1 — Khung Home và trạng thái xu — `HOÀN THÀNH`

- Chuẩn hóa thanh trên, số dư Yuzu, Yuzu chờ đồng bộ và thông báo.
- Bỏ nút điểm danh nhận xu riêng.
- Hiển thị bảng xếp hạng rút gọn và thời điểm cập nhật cuối khi offline.
- Kiểm tra: cùng một tài khoản phải thấy số dư nhất quán sau khi đổi màn và mở lại ứng dụng.

Kết quả ngày 27/09/2026:

- Home đọc số dư Yuzu đã xác nhận từ hồ sơ Supabase và lưu snapshot cục bộ theo từng tài khoản để mở lại khi offline.
- Giao diện đã có số dư, vùng Yuzu chờ đồng bộ, badge thông báo chưa đọc, streak chỉ đọc và thẻ bảng xếp hạng rút gọn.
- Đã xóa provider điểm danh cũ; không còn nút `Thắp lửa` hoặc hành động tự nhận xu.
- Chưa dùng `study_points` làm Yuzu tuần vì chưa có point ledger tuần. Thẻ xếp hạng hiển thị trạng thái chưa có dữ liệu xác nhận; dữ liệu thật thuộc H5C.
- Analyzer sạch; 13/13 test Home/navigation, 675 test toàn dự án với 1 live test được skip, Web release và APK debug build thành công.
- Chrome widget test riêng bị treo trong môi trường máy hiện tại và bị dừng sau timeout; Web vẫn đã qua build release và widget test trên Flutter VM.
- Android 13 CPH2375 đã cài APK Staging và mở Home thành công: số dư, lời chào, streak chỉ đọc, leaderboard empty-state, thông báo, Cài đặt và bottom navigation render đúng; log khởi động không có crash, Flutter error hoặc overflow.

### H2 — Photo Note, mục tiêu ngày và bản đồ — `HOÀN THÀNH STAGING 28/09/2026`

- Mỗi node đại diện đúng một ngày và chỉ dùng ảnh thuộc ngày đó.
- Thêm trạng thái node ở mục 6.2 và hành động tương ứng.
- Hiển thị mục tiêu, số từ hợp lệ, số còn thiếu và lý do ảnh/từ bị loại.
- Kiểm tra biên 23:59/00:00 và trường hợp kết quả xử lý ảnh về sau nửa đêm.

Kết quả ngày 27/09/2026:

- Home đã đọc Photo Note đang hoạt động từ Library SQLite theo đúng tài khoản,
  gom ảnh bằng `capturedAt` và chỉ tải snapshot nằm trong tuần/tháng đang xem.
  Thời gian kết quả nhận diện trả về không được dùng để đổi ngày của ảnh.
- Thẻ nhiệm vụ hiển thị mục tiêu, từ hợp lệ duy nhất, số còn thiếu, tiến trình,
  thưởng dự kiến và lý do chưa tính gồm từ trùng, ảnh mờ, không nhận diện được,
  sai ngôn ngữ hoặc đang xử lý. Ảnh đang xử lý có thông báo không bị phạt.
- Bản đồ có chế độ Tuần/Tháng và đủ contract sáu trạng thái. Dữ liệu hiện tại
  xác định thật các trạng thái `Chưa đủ dữ liệu`, `Sẵn sàng` và `Đã quá hạn`;
  `Đang học`, `Chờ đồng bộ`, `Đã hoàn thành` đã có model/UI nhưng chỉ nhận dữ
  liệu thật sau H3/H4. Nút bắt đầu/tiếp tục hiện thông báo rõ H3 chưa triển khai,
  không giả lập gameplay hoặc thưởng.
- Mục tiêu ngày đọc từ `user_settings.daily_target_words`, cache theo tài khoản
  để có fallback offline. Chưa có bản ghi mục tiêu bất biến theo từng ngày nên
  lịch sử hiện dùng mục tiêu hiện tại; việc đổi mục tiêu chỉ áp dụng ngày sau
  vẫn cần contract dữ liệu ở increment tiếp theo.
- Unit/widget regression kiểm tra 23:59/00:00, kết quả xử lý sau nửa đêm, khử
  trùng, lý do loại, toàn bộ trạng thái, loading offline và viewport 320px.
  Analyzer toàn dự án sạch; full Flutter suite có lần xác nhận cuối
  `success=true`; Web Staging release và Android Staging APK build thành công.
- Android 13 CPH2375 đã cài đè giữ dữ liệu và xác nhận Home offline thoát loading,
  thẻ nhiệm vụ + bản đồ render đúng, đổi Tuần/Tháng được và không có crash,
  Flutter error, RenderFlex hay overflow trong log PID.
- H2 chưa được chuyển sang `HOÀN THÀNH` vì `user_settings` chưa có múi giờ tài
  khoản. Runtime đang dùng múi giờ thiết bị và hiển thị công khai giới hạn này;
  do đó chưa bảo đảm chống đổi giờ thiết bị hoặc nhất quán đa thiết bị. Chrome
  test runner riêng cũng không trả kết quả và đã được dừng; Web chỉ mới qua
  release build, chưa có live browser smoke cho H2.
- Không đổi schema/migration, không apply Staging, không deploy và không push Git.

#### Quyết định UX H2 đã duyệt ngày 27/09/2026

- Người dùng chỉ chọn mục tiêu một lần trong onboarding hoặc Cài đặt; Home
  không hỏi lại mục tiêu mỗi ngày.
- Múi giờ được tự nhận khi thiết lập tài khoản, hiển thị và cho phép đổi trong
  Cài đặt. Tên múi giờ phải dùng định danh có vùng như `Asia/Bangkok`, không chỉ
  lưu giờ lệch `UTC+7`, để xử lý đúng các quốc gia có giờ mùa hè.
- Nhiệm vụ ngày được tạo ngầm. Nếu ứng dụng đang mở, ngày mới được nhận tại
  00:00 theo múi giờ tài khoản; nếu ứng dụng đang đóng, nhiệm vụ được bảo đảm
  tồn tại ở lần mở hoặc thao tác đầu tiên. Tạo lại từ nhiều thiết bị phải trả về
  cùng một nhiệm vụ, không sinh bản trùng.
- Khi nhiệm vụ được tạo, hệ thống đóng băng ngày, múi giờ và mục tiêu của ngày
  đó. Đổi mục tiêu hoặc múi giờ trong ngày chỉ áp dụng cho nhiệm vụ ngày sau.
- Home sau khi hoàn thiện chỉ hiển thị tiến trình như `7/10 từ`, số còn thiếu,
  trạng thái và một hành động chính; không hiển thị bộ chọn mục tiêu.
- Bản đồ giữ bộ chọn Tuần/Tháng và sẽ có điều hướng kỳ trước, kỳ sau, quay về
  hôm nay. Ảnh lỗi có hành động `Chụp lại`; người dùng có thể `Chụp thêm` hoặc
  chọn ảnh được chụp trong chính ngày đó từ Thư viện.

Thứ tự thực hiện phần H2 còn lại:

1. **H2A — Hợp đồng ngày — `HOÀN THÀNH 28/09/2026`:** lưu múi giờ tài khoản
   và nhiệm vụ ngày có mục tiêu bất biến; có ràng buộc một tài khoản/một ngày
   và cache offline theo owner.
2. **H2B — Tạo ngầm — `HOÀN THÀNH CỤC BỘ 28/09/2026`:** tự bảo đảm nhiệm vụ
   lúc 00:00/lần mở đầu tiên, đổi cài đặt chỉ tác động ngày sau và đồng bộ
   không tạo bản trùng.
3. **H2C — UX cuối — `HOÀN THÀNH CỤC BỘ 28/09/2026`:** thu gọn thẻ Home,
   thêm điều hướng thời gian và ba hành động ảnh `Chụp thêm`, `Chụp lại`,
   `Chọn ảnh cùng ngày`.
4. **H2D — Gate — `HOÀN THÀNH STAGING 28/09/2026`:**
   kiểm tra đổi mục tiêu giữa ngày, đổi múi giờ, hai thiết bị, offline qua
   00:00, Web và Android. Chỉ sau smoke test Android thật mới đổi trạng thái H2
   thành `HOÀN THÀNH`.

Kết quả H2A ngày 28/09/2026:

- Migration additive thêm `user_settings.time_zone` và `daily_missions`; timezone
  chỉ nhận IANA region có thật như `Asia/Bangkok`, không nhận offset `UTC+7`.
  Tài khoản cũ giữ `NULL` rõ ràng để H2B nâng cấp an toàn, không đoán múi giờ.
- Khóa ghép `(user_id, mission_date)` bảo đảm một tài khoản/một ngày chỉ có một
  nhiệm vụ. `time_zone`, `target_words`, ngày và thời điểm tạo là snapshot bất
  biến; client authenticated chỉ được đọc row của chính mình, chưa được tự ghi.
- Library SQLite nâng v3→v4 với cache `daily_missions` owner-scoped, giữ dữ liệu
  cũ khi nâng cấp, ghi lặp cùng snapshot là idempotent và từ chối snapshot xung
  đột. Chưa nối cache này vào Home vì việc tạo/pull nhiệm vụ thuộc H2B.
- PostgreSQL 18 tạm thời pass 11/11 kiểm tra IANA, uniqueness, immutability,
  quyền ghi và RLS. Home + Library local pass 68/68; full Flutter pass 690 với
  1 live test opt-in được skip; analyzer toàn dự án sạch. Exact linked Staging
  dry-run sạch và chỉ liệt kê migration H2A này là pending.
- Migration chưa apply Staging/Production; không deploy, không đổi remote data
  và không push Git. Đây là trạng thái tại cổng H2A; H2 tổng thể hiện vẫn chờ
  H2C–H2D.

Kết quả H2B ngày 28/09/2026:

- Migration additive `20260928130000_ensure_daily_mission.sql` bổ sung ba biên
  UTC do server tính (`starts_at`, `ends_at`, `next_day_ends_at`) và RPC
  authenticated `ensure_daily_mission`. RPC khóa setting của owner, chỉ dùng
  timezone thiết bị để thiết lập lần đầu, sau đó timezone tài khoản luôn thắng;
  `INSERT ... ON CONFLICT DO NOTHING` trả cùng snapshot khi nhiều thiết bị gọi.
- Runtime Flutter dùng `flutter_timezone 3.0.1` để lấy IANA region, bảo đảm
  mission khi đăng nhập/mở app/resume và đặt một timer tới đúng `ends_at` thay
  vì polling. Logout/đổi account hủy timer và xóa snapshot owner cũ.
- SQLite cache lưu trạng thái `local_only/synced` cùng biên ngày. Khi offline,
  app dùng mission hiện tại hoặc biên ngày kế tiếp đã được server cache sẵn;
  khi reconnect, snapshot canonical từ server thay bản local xung đột. Home đọc
  target bất biến theo từng mission và chỉ dùng device-offset fallback khi chưa
  có snapshot.
- PostgreSQL 18 cô lập pass 21/21, gồm gọi lặp/multi-device, setting chỉ áp dụng
  ngày sau, owner/RLS, first-time timezone và ngày DST 25 giờ. Cụm Flutter H2B
  pass 27/27; analyzer toàn repo sạch; full Flutter pass 702 + 1 opt-in skip;
  Web release và Android debug APK build thành công.
- Linked Staging dry-run trả `dryRun=true` và chỉ liệt kê H2A + H2B pending.
  Chưa apply migration, chưa ghi remote data, chưa deploy và chưa push Git.
  Tại cổng H2B, H2 tổng thể vẫn chờ H2C và H2D.

Kết quả H2C ngày 28/09/2026:

- Thẻ nhiệm vụ Home được thu gọn thành tiến độ `hợp lệ/mục tiêu`, thanh tiến
  độ, số còn thiếu, trạng thái, thưởng dự kiến và một hành động chính. Các lý
  do ảnh không được tính vẫn hiển thị rõ, không biến ảnh đang xử lý thành lỗi
  của người dùng.
- Bản đồ Tuần/Tháng có điều hướng kỳ trước, kỳ sau và quay về hôm nay. Việc xem
  kỳ lịch sử không làm mất thẻ nhiệm vụ hôm nay; hai luồng dữ liệu vẫn cập nhật
  phản ứng độc lập mà không truy vấn một khoảng lịch sử quá rộng.
- Ngày thiếu dữ liệu hỗ trợ `Chụp thêm`; ảnh lỗi nhận diện hỗ trợ `Chụp lại`;
  `Chọn ảnh cùng ngày` mở Library với đúng biên UTC nửa mở `[starts_at,
  ends_at)`. Các nút mới có vùng chạm tối thiểu 48 px và co dọc trên màn hình
  hẹp.
- H2C không đổi schema, migration, write path, outbox hay đồng bộ. Nhóm test
  H2C/Home/Library pass 43/43; analyzer toàn dự án sạch; full Flutter pass 707
  + 1 live test opt-in skip; Web release và Android debug APK build thành công.
  Cảnh báo WASM hiện có của `flutter_tts` không chặn Web JavaScript build.
- Chưa apply migration H2A/H2B, chưa ghi remote data, deploy hoặc push. H2 tổng
  thể còn H2D để kiểm tra đổi mục tiêu/múi giờ giữa ngày, hai thiết bị, offline
  qua 00:00 và gate thiết bị/Web.

Kết quả H2D ngày 28/09/2026:

- Sửa rollover offline để snapshot timezone tài khoản đã cache luôn thắng
  timezone thiết bị, kể cả khi người dùng di chuyển hoặc plugin timezone lỗi.
  Mục tiêu và timezone của mission hiện tại vẫn bất biến; setting mới chỉ áp
  dụng cho mission ngày sau.
- PostgreSQL 18 cô lập pass 22/22, bao phủ hai thiết bị với timezone phát hiện
  khác nhau vẫn nhận cùng row, đổi mục tiêu/timezone giữa ngày, ngày sau và
  DST. Runtime Flutter có test refresh khi resume và đúng biên ngày cache khi
  offline.
- Home đã qua gate màn hình rộng 320 px với Android text scale 200%; các header
  và legend co dòng thay vì overflow. Nhóm H2D/Home/Library mục tiêu pass 69/69;
  full Flutter pass 712 + 1 live test opt-in skip; analyzer toàn dự án sạch.
- Web release build và browser startup smoke thành công; Android debug APK build
  thành công. Chrome widget-test runner riêng bị treo trong môi trường này,
  nhưng không chặn JavaScript release build. Mobile audit tổng quát báo nhiều
  false positive do quét generated Web/Dart và coi icon/font size là touch
  target; các control H2 được kiểm bằng widget test 48 px và font scale 200%.
- Đã tạo backup Staging `public/private` mã hóa DPAPI và xác minh restore list,
  hash cùng round-trip. Hai migration H2A/H2B đã apply đúng exact Staging
  `nxteaznowkfennxpqjmt`; migration history khớp và dry-run hậu apply trả
  `upToDate=true`. Production không bị truy cập.
- APK exact-Staging đã cài đè giữ app data lên CPH2375 Android 13. Online tạo
  đúng một mission ngày 28/09 và timezone tài khoản; nhiều lần restart không
  tạo bản trùng. Khi Wi-Fi/mobile data đều tắt, cold launch vẫn render mission
  `0/10` từ cache, không crash; mạng sau đó được khôi phục đúng trạng thái cũ.
- Migration idempotent `20260928140000_enable_users_realtime.sql` đã thêm
  `public.users` vào publication `supabase_realtime` mà không đổi RLS/grant.
  SQL gate pass 23/23; backup DPAPI mới được xác minh; exact-Staging dry-run
  chỉ liệt kê migration này, apply thành công và hậu kiểm `upToDate=true`.
- Sau apply, online cold launch không còn banner offline; khi tắt cả Wi-Fi và
  mobile data, banner cache offline xuất hiện đúng và mission vẫn render; sau
  restore/reconnect banner biến mất lại. Không có Auth/PostgREST/Realtime/crash
  error, mission vẫn duy nhất `1 owner-day`. H2D và H2 được chốt hoàn thành trên
  Staging.
- Staging có đúng một remote mission row và một setting timezone được ghi bởi
  smoke test đã duyệt. Chưa deploy Edge Function, chưa chạm Production và chưa
  push Git.

### H3 — Game hoàn thành 100% và lưu tiếp tục — `HOÀN THÀNH 2026-09-30`

- Dùng chung luật mastery cho game sắp xếp và game điền từ.
- Loại bỏ thưởng theo từng câu, thưởng kết quả một phần và cơ chế hết mạng trong nhiệm vụ ngày.
- Lưu tiến trình khi thoát/đóng ứng dụng; khôi phục đúng danh sách từ còn lại.
- Kiểm tra: thoát nhiều lần không sinh thưởng; chỉ hoàn thành 100% mới tạo kết quả.

#### H3.1. Kiến trúc gameplay đã chốt

- Hai game tách riêng widget, interaction, grader và test nhưng dùng chung đúng
  một `LessonSession`, mastery queue, tiến trình `X/Y`, persistence và kết quả.
- Nhiệm vụ ngày tự phối hợp hai game; người chơi không phải chọn game và không
  có hai tiến trình cạnh tranh. Chế độ ôn lại từ Library mới cho phép chọn
  `Ghép từ`, `Điền chữ` hoặc `Trộn cả hai`.
- Một từ hợp lệ tạo một mastery item owner-scoped gồm ID nguồn ổn định,
  Photo Note, MediaAsset, target detection/annotation, bbox, effective answer,
  source revision và rule version. Không dùng list index hoặc đường dẫn file làm
  identity.
- Danh sách từ của session được đóng băng khi bắt đầu. Photo Note tạo thêm sau
  đó không chen vào session đang chơi; Home đọc `X/Y` của session cho đến khi
  session kết thúc.
- Mỗi từ chỉ cần trả lời đúng một lần qua một trong hai game. Đúng thì chuyển
  thành `mastered`; sai thì quay lại cuối hàng đợi và có question/attempt ID
  mới khi xuất hiện lại.

#### H3.2. Game 1 — Ghép từ với đồ vật được đánh số

- `photo_order_quiz` dùng một ảnh local có 2–4 target hợp lệ. Mỗi bbox được gắn
  marker số rõ ràng; bên dưới là các thẻ từ bị xáo trộn và các slot tương ứng.
- Người chơi có thể kéo thả hoặc chạm thẻ rồi chạm slot; drag không được là
  thao tác duy nhất. Mọi touch target tối thiểu 48 dp và cách nhau ít nhất 8 dp.
- Nút `Kiểm tra` chỉ bật khi mọi slot đã có đúng một card ID và không có card
  lạ/trùng. Grader so sánh theo target/card ID đã frozen, không so theo index UI.
- Chấm từng slot: từ đặt đúng được mastery ngay; từ đặt sai hiển thị mapping đúng
  rồi quay lại queue. Một câu sai một phần không bắt người chơi làm lại các từ
  đã đặt đúng.
- Canonical mapping là marker số nhìn thấy trên ảnh → target ID → answer ID.
  Người chơi không phải đoán `displayOrder`, trái→phải hoặc một thứ tự ẩn.

#### H3.3. Game 2 — Điền từ cho đồ vật được chỉ định

- `photo_letter_fill` hiển thị ảnh và highlight đúng một target bbox; ảnh có
  nhiều đồ vật nhưng không được bắt người chơi đoán target.
- Một `TextField` thật là nguồn input để giữ IME, Unicode và accessibility;
  các ô chữ chỉ là presentation. Input rỗng hoặc quá giới hạn không tạo attempt.
- Normalizer v1 dùng Unicode NFC, trim khoảng trắng đầu/cuối và so sánh không
  phân biệt hoa/thường. Khoảng trắng bên trong, apostrophe và dấu nối vẫn có ý
  nghĩa; không tự nhận đồng nghĩa hoặc biến thể số nhiều.
- Submit hợp lệ chốt đúng một verdict. Đúng thì mastery; sai thì hiện đáp án
  frozen và đưa item về cuối queue, không cho sửa attempt cũ để đổi verdict.

#### H3.4. Điều phối câu hỏi và state machine

- Ưu tiên Game 1 khi queue có 2–4 item pending cùng một Photo Note và đều có
  target rõ; item đơn hoặc item còn lại dùng Game 2. Một item sai ở Game 1 có
  thể xuất hiện lại trong Game 2 và ngược lại.
- State chung: `loading → ready → answering → submitting → feedback → next`;
  `next` quay lại `answering` hoặc sang `completed`. Nhánh khác gồm `empty`,
  `error`, `paused`, `blocked`, `abandoned` và `expired`.
- `question_instance_id` chỉ có một verdict; `attempt_id` retry trả lại verdict
  đã commit, payload khác dùng cùng ID bị conflict. Callback của câu cũ không
  được sửa câu mới.
- Chỉ khi `completed_items == total_items`, queue rỗng và session chưa hoàn
  thành thì mới tạo đúng một local completion result. H3 không ghi Yuzu, XP,
  streak, SRS hoặc leaderboard; H4 xử lý sync và H5 xử lý thưởng.

#### H3.5. Pause, bỏ bài, hết hạn và ôn lại

- X, Back, app background hoặc app bị đóng chuyển thành `paused`, tự lưu câu
  hiện tại, draft/slot placement, mastery set và queue. Đây không phải bỏ bài,
  không phạt và không tạo kết quả.
- `Bỏ bài` là action riêng có xác nhận. Session chuyển `abandoned` nhưng giữ
  snapshot, `X/Y` và attempt history; mất quyền thưởng nhiệm vụ ngày và không
  được tự quay lại trạng thái active.
- Nhiệm vụ chỉ hiển thị trên bản đồ của tháng lịch tương ứng. Dữ liệu cũ vẫn
  được giữ dưới dạng metadata owner-scoped; không lưu bản sao bản đồ tháng hoặc
  nhân bản ảnh.
- Ôn lại tạo review session mới từ dữ liệu người chơi chủ động chọn trong
  Library, không sửa session/result cũ và không phục hồi quyền thưởng.
- Sau `ends_at` session được đánh dấu hoàn thành muộn; sau
  `next_day_ends_at` chuyển `expired` và chỉ còn quyền ôn tập. H3 chỉ lưu thời
  điểm; mức thưởng đúng hạn/muộn thuộc H5.
- Correction mới không sửa answer của session đang chơi. Nếu nguồn bị xóa hoặc
  media mất, ngừng hiển thị ngay và chuyển `blocked`; không tự giảm mẫu số `Y`.

#### H3.6. Ranh giới quảng cáo

- Hai game không chứa SDK hoặc widget quảng cáo. Quảng cáo là concern của
  lesson shell và chỉ được phép ở `intro`, `completed`, Home, lịch sử hoặc
  Library; `playing`, `submitting` và `feedback` luôn cấm.
- Không đặt banner sát ảnh tương tác, bàn phím, card/slot, nút `Kiểm tra`,
  `Tiếp tục`, Back hoặc X. Gameplay không chừa khoảng trống quảng cáo.
- Khi rollout quảng cáo sau H3, dùng vùng adaptive có kích thước ổn định trên
  màn được phép, test unit ID và dispose đúng lifecycle. Interstitial nếu có chỉ
  được cân nhắc sau khi completion đã commit và trước màn kết quả, không sau
  từng câu hoặc khi chuyển game.
- H3 chỉ khóa `LessonStage`/ad policy để không phải sửa gameplay về sau; chưa
  thêm dependency, ad unit, consent flow hoặc network request quảng cáo.

#### H3.7. Kế hoạch triển khai và gate

1. **H3A — Domain/mastery — `HOÀN THÀNH 2026-09-29`:** model immutable,
   normalizer NFC, grader hai game, queue reducer và idempotency thuần Dart;
   unit test đúng/sai/requeue/100% pass 11/11.
2. **H3B — Local persistence — `HOÀN THÀNH 2026-09-29`:** session
   owner-scoped, frozen items, attempts và completion result; Library SQLite
   v5 giữ dữ liệu v4, transaction checkpoint, account isolation và reopen test;
   schema/store pass 12/12, `db_status.md` đã cập nhật.
3. **H3C — Question builder/controller — `HOÀN THÀNH 2026-09-29`:** đọc
   `PhotoNoteSnapshot` qua Library repository, chỉ dùng media local active,
   frozen source revision, phối hợp hai game, review mode và xử lý invalidation.
   Regression test có cả pause ngay tại feedback để draft câu cũ không lọt sang
   câu kế tiếp.
4. **H3D — UI/navigation — `HOÀN THÀNH 2026-09-29`:** lesson shell, hai game
   responsive, 48 dp/TalkBack, Back/X lifecycle, Home `Bắt đầu`/`Tiếp tục X/Y`,
   empty/error/blocked/result và điểm vào ôn lại theo game từ Library.
5. **H3E — Verification — `HOÀN THÀNH 2026-09-30`:**
   analyzer toàn dự án sạch; full suite pass 748, skip 1; Web release và APK
   debug build thành công. APK exact-Staging đã cài trên CPH2375 Android 13;
   phiên đăng nhập được khôi phục, online cold-start render Home, offline thật
   vẫn render cache kèm cảnh báo và reconnect bỏ cảnh báo. Wi-Fi/mobile data đã
   được khôi phục đúng trạng thái ban đầu `1/1`. Tài khoản smoke hiện có `0/10`
   từ hợp lệ và Library chưa có Photo Note nên chưa thể mở lesson để kiểm tra
   background/force-stop, current draft và queue trên thiết bị thật; các contract
   này mới có bằng chứng tự động bằng SQLite/controller/widget test.

Kết quả rà soát UX từ ảnh thiết bị ngày 30/09/2026:

- Marker số trước đây nằm trong constraint của bbox nên bị co/cắt theo đồ vật
  nhỏ. Badge nay tách khỏi bbox, cố định 36 dp, nền vàng, viền/chữ đen và luôn
  được clamp trong ảnh; khung bbox dùng viền vàng có outline đen.
- Lesson dùng nền giấy sáng cố định nhưng trước đây vẫn kế thừa chữ/icon trắng
  khi thiết bị bật dark mode. Màn lesson nay dùng light theme cục bộ để AppBar,
  thẻ từ, chip số, input và feedback giữ tương phản đúng trên nền sáng.
- Ảnh local nhiều megapixel nay decode theo kích thước hiển thị vật lý và nằm
  trong `RepaintBoundary`, tránh decode/repaint nguyên ảnh khi thao tác thẻ.
- Regression mini-game pass 34/34 và analyzer toàn dự án sạch. APK đã smoke
  trước đó là debug; lần đánh giá độ mượt tiếp theo phải dùng bản release
  exact-Staging để không trộn overhead của Dart VM/debugger vào UX thực tế.
- Android manifest không khai báo service/receiver/tool điều khiển màn hình;
  ADB chỉ chạy trên máy phát triển và không được cài thành ứng dụng trên máy test.
- Runner exact-Staging hỗ trợ chọn `debug/profile/release` nhưng vẫn giữ mặc
  định `debug`. APK release đã cài đè giữ dữ liệu trên CPH2375; Android xác nhận
  package không debuggable, không có Dart VM service, cold-start `3.943 s`, Home
  giữ phiên đăng nhập và lesson giữ draft cũ. Marker 1–4 cùng toàn bộ chữ/chip
  đã được xác nhận trực quan rõ trên máy thật.
- `gfxinfo` của thiết bị không thu frame Flutter/Impeller (`0` frame), nên không
  dùng kết quả đó để tuyên bố hết jank. Cần người dùng chơi trực tiếp bản release
  và gửi ảnh/video nếu vẫn có khựng để khoanh đúng thao tác.
- Người dùng đã chơi trực tiếp bản release và xác nhận tốc độ thực tế tăng từ
  khoảng 24 FPS lên 30 FPS. Mốc này đủ để chốt H3; tối ưu sâu hơn được dời sau
  khi hoàn tất Home và không mở rộng phạm vi H4.

Gate hoàn thành H3: thoát/khởi động lại nhiều lần khôi phục đúng current draft
và queue; sai quay lại, đúng không lặp; account khác không thấy session; 99%
không có result; 100% chỉ có một result; không có Yuzu/streak/leaderboard write.

### H4 — Trải nghiệm online/offline và đồng bộ — `HOÀN THÀNH; EXACT-STAGING + ANDROID VERIFIED 2026-10-04`

- Hiển thị rõ `Chờ đồng bộ`, `Đã đồng bộ` và `Đồng bộ lỗi`.
- Tách Yuzu chờ khỏi số dư có thể chi tiêu.
- Không cập nhật bảng xếp hạng bằng kết quả chỉ còn trên máy.
- Kiểm tra: hoàn thành offline, đóng/mở ứng dụng, kết nối lại và đồng bộ không bị mất hoặc cộng hai lần.

#### H4.1. Hợp đồng và local outbox

- Library SQLite được nâng additive từ v5 lên v6. Completion đủ điều kiện của
  nhiệm vụ ngày có trạng thái `pending → syncing → synced` hoặc `failed`; review
  session là `not_applicable` và không bao giờ vào hàng đợi.
- Payload gameplay vẫn immutable; chỉ metadata vận hành sync được cập nhật.
  Bản nâng cấp v5→v6 chuyển completion nhiệm vụ ngày cũ sang `pending`, giữ dữ
  liệu owner-scoped và khôi phục item sau restart mà không tạo result thứ hai.
- Coordinator chạy khi đăng nhập, app resume, có thay đổi local hoặc mạng trở
  lại. Retry dùng backoff 5 giây đến 6 giờ; conflict payload là lỗi chặn và chỉ
  retry khi người dùng bấm rõ ràng.
- Evidence gửi server không chứa đường dẫn ảnh local, Photo Note/media ID,
  bounding box, raw Vision hay fingerprint ngoài contract cần thiết. GT5 bổ sung
  canonical `word` cho từng item đã mastery để tạo projection chữ opt-in trong
  learning group; attempt input thô và ảnh vẫn không được gửi cho giáo viên.

#### H4.2. Backend idempotent và ranh giới H5

- Migration `20260930160000_add_lesson_completion_sync.sql` tạo receipt
  owner-scoped, immutable và RPC `sync_lesson_completion`. Client authenticated
  chỉ được đọc receipt của mình và không thể insert/update/delete trực tiếp.
- RPC chỉ nhận completion 100%, đối chiếu daily mission và evidence mastery.
  Retry giống hệt trả lại cùng receipt; payload khác dùng cùng result/session/day
  bị từ chối. Race giữa hai request đồng thời được serialize bằng unique indexes
  và `ON CONFLICT DO NOTHING` rồi đọc lại receipt thắng cuộc.
- Projection GT5 chỉ chạy sau khi receipt được server chấp nhận và chỉ cho group
  mà học viên đang active đã bật chia sẻ. Build phải bật
  `LESSON_RESULT_SYNC_ENABLED=true`; mặc định OFF không tự tạo dữ liệu cloud.
- H4 tuyệt đối không cộng `total_coins`, không đổi streak và không ghi điểm tuần
  hay leaderboard. Receipt giữ `reward_status=pending`; H5 mới quyết định mức
  100/130/150, phạt muộn và settlement server-authoritative.

#### H4.3. UX và bằng chứng xác minh

- Home và màn kết quả phản ánh ba trạng thái thật. `Đồng bộ lỗi` có nút
  `Thử đồng bộ lại`; completion offline vẫn mở được sau restart và không bị khóa
  khỏi màn kết quả.
- Yuzu dự kiến được hiển thị riêng là `đang chờ`, không nhập vào số dư có thể
  chi tiêu. Receipt local/remote chưa settlement không làm thay đổi leaderboard.
- PostgreSQL 18 isolated pass 35/35; SQLite schema/store pass 15/15; coordinator
  pass 3/3; nhóm Home + mini-game + SQLite pass 92/92; full Flutter pass 756,
  skip 1; analyzer sạch.
- Exact-Staging `nxteaznowkfennxpqjmt` đã backup DPAPI 371.127 byte, dry-run chỉ
  có đúng migration H4, apply thành công và post-dry-run `upToDate=true`.
  Synthetic smoke pass 6 nhóm: insert/idempotent retry, conflict, quyền RPC/RLS,
  không đổi Yuzu/streak và cleanup còn 0 fixture.
- APK release exact-Staging với `LESSON_RESULT_SYNC_ENABLED=true` đã được cài đè
  trên CPH2375 bằng `adb install -r`, giữ nguyên session và dữ liệu local. Increment
  H5D xác nhận cold-start online, cache offline và tự reconnect trên cùng tiến
  trình; không tạo completion fixture mới trên tài khoản thật trong bước này.

### H5 — Hoàn thiện Home — `HOÀN THÀNH`

#### H5A — Thưởng lần đầu, chuỗi và chống lạm phát

- Áp dụng bảng thưởng 100/130/150 và mức muộn 67/87/100.
- Mua vật phẩm không làm giảm Yuzu tuần.
- Kiểm tra các mốc 99%, 100%, 149%, 150%, 199% và 200% mục tiêu.
- Settlement server-authoritative đã apply exact Staging. Ví, Yuzu tuần và
  streak được ghi trong cùng transaction; ledger chỉ đọc với client.

#### H5B — Chơi lại có thưởng và ôn tập không thưởng

- Chơi lại có thưởng đúng một lần bằng một phần ba; các lần sau bằng 0.
- Replay dùng snapshot đóng băng, chỉ lượt hai nhận `floor(lần đầu / 3)`, hết
  cửa sổ 24 giờ nhận 0. SQLite v8 lưu ánh xạ replay additive, không rebuild
  tiến trình; lượt ba trở đi vẫn mở được dưới dạng ôn tập local không sync/thưởng.

#### H5C — Bảng xếp hạng và phản hồi người dùng

- Làm mới vị trí sau khi kết quả online hoặc offline được xác nhận.
- Giải thích điểm nào đã vào tuần và điểm nào chỉ vào ví.
- Có phản hồi dễ hiểu khi đồng bộ chậm hoặc thất bại.
- Kiểm tra hai tài khoản trên hai thiết bị thấy thứ hạng giống nhau sau khi đồng bộ.
- RPC chỉ trả tài khoản hiện tại và bạn bè accepted hai chiều, xếp hạng từ
  `weekly_yuzu` đã settlement. Home cache theo owner, hiển thị timestamp khi
  offline, avatar/tên/hạng/điểm và giải thích replay chỉ vào ví. Synthetic
  exact-Staging hai tài khoản xác nhận cùng ordering/rank sau đồng bộ.

#### H5D — Điều hướng và kiểm thử tích hợp

- Kiểm tra Camera, Thư viện, Pet Shop, Bạn bè và bong bóng Chat từ Home.
- Kiểm tra giao diện nhỏ trên điện thoại và giao diện web.
- Chạy toàn bộ kịch bản ở mục 13 trước khi đưa lên staging.
- Chỉ đề nghị deploy sau khi không còn lỗi chặn luồng chính.
- Home cache nay retry stream hồ sơ theo backoff 2/5/15/30 giây sau lỗi tạm thời,
  thay vì kẹt offline đến lần restart tiếp theo. Regression test tái hiện đúng
  cold-start race và xác nhận cache offline tự chuyển sang dữ liệu online.
- SQL isolated pass 58/58; Home pass 49/49; full Flutter pass 763 + 1 skip;
  analyzer sạch; Web release và APK release exact-Staging build thành công.
- CPH2375 cài đè APK giữ dữ liệu, giữ session và pass cold-start online, offline
  cache, reconnect không restart. Smoke thật mở đúng Thư viện, Pet Shop, Bạn bè,
  Camera và hộp thư Chat; không có crash/Flutter/SQLite exception được ghi nhận.
- Final gate 06/10/2026 chạy lại SQL 58/58, full Flutter 763 + 1 skip,
  analyzer sạch, synthetic exact-Staging 9 nhóm với cleanup còn 0 fixture, Web
  release và APK release 70,7 MB đều pass. ADB không thấy thiết bị ở lần chạy
  này nên bằng chứng smoke Android gần nhất vẫn là lần pass ngày 04/10/2026.

## 13. Kịch bản UX bắt buộc trước staging

1. Người dùng đặt mục tiêu 10 từ, có đúng 10 từ, hoàn thành 100% online và nhận 100 Yuzu vào cả ví lẫn tuần.
2. Người dùng có 15 từ và 20 từ để xác nhận đúng hai mốc 130 và 150 Yuzu.
3. Người dùng chụp đủ ảnh nhưng từ hợp lệ dưới mục tiêu; giao diện nêu đúng nguyên nhân và cho bổ sung ảnh.
4. Người dùng chụp ảnh lúc 23:59; ảnh vẫn nằm trong Photo Note ngày cũ sau 00:00.
5. Người dùng thoát ở tiến trình X/Y, mở lại và tiếp tục đúng phần còn lại; chưa có xu trước khi đạt 100%.
6. Người dùng hoàn thành offline, thấy chuỗi và Yuzu chờ; chưa thể mua hàng và chưa lên hạng trước khi đồng bộ.
7. Kết nối lại và đồng bộ thành công đúng một lần dù ứng dụng được mở lại hoặc người dùng bấm thử lại nhiều lần.
8. Chơi lại lần thứ hai nhận một phần ba vào ví nhưng không vào tuần; lần thứ ba nhận 0.
9. Mua vật phẩm làm giảm số dư nhưng không làm thay đổi thứ hạng tuần.
10. Hai tài khoản trên web và điện thoại nhìn thấy kết quả xếp hạng giống nhau sau khi dữ liệu được xác nhận.
11. Bong bóng Chat vẫn xuất hiện và mở đúng cuộc trò chuyện người-với-người trên cả web và điện thoại.

## 14. Điều kiện hoàn thành Home

- Tất cả trạng thái và nút bấm trong tài liệu này có mặt trên web và ứng dụng hoặc được đánh dấu rõ là chưa triển khai.
- Không còn nguồn điểm hoặc tên tiền tệ khác ngoài xu Yuzu.
- Không cộng xu cho bài dở dang, câu đúng riêng lẻ hoặc lượt ôn tập từ lần thứ ba.
- Kết quả offline không bị mất, không được chi tiêu sớm và không bị ghi nhận hai lần.
- Ranh giới ngày, mục tiêu từ, chuỗi, chơi lại và Yuzu tuần hoạt động đúng các kịch bản mục 13.
- Bản đồ dùng đúng dữ liệu Photo Note theo ngày.
- Bảng xếp hạng chỉ dùng Yuzu tuần đã được xác nhận.
- Điều hướng Camera, Thư viện, Pet Shop, Bạn bè và Chat hoạt động trên cả web và điện thoại.
- Chưa deploy staging nếu còn lỗi chặn nhiệm vụ ngày, lưu tiến trình, đồng bộ hoặc tính thưởng.
