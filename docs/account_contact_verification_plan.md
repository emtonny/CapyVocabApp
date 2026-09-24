# Kế hoạch xác nhận email và số điện thoại

> Chốt sản phẩm: **2026-09-24**
> Trạng thái: **APPROVED / PENDING IMPLEMENTATION**
> Phạm vi: Android, iOS và Web; chưa có thay đổi dữ liệu hoặc triển khai từ tài
> liệu này.

## 1. Mục tiêu đã chốt

- Email đã xác nhận dùng để đăng nhập, xác nhận tài khoản và lấy lại mật khẩu.
- Số điện thoại đã xác nhận bằng SMS dùng để bảo vệ tài khoản và hạn chế tạo
  nhiều tài khoản nhằm nhận lại tài nguyên hoặc ưu đãi.
- Username là cách duy nhất để tìm bạn.
- Email và số điện thoại mặc định ẩn. Khi người dùng bật hiển thị, chỉ bạn bè đã
  chấp nhận mới được xem; người lạ và tài khoản chỉ có lời mời chờ không được xem.
- Chấp nhận số điện thoại từ mọi quốc gia mà nhà cung cấp SMS có thể gửi tới;
  ứng dụng không tự giới hạn một danh sách quốc gia riêng.
- Đổi email hoặc số điện thoại không làm mất gói đang còn hạn, không cấp lại ưu
  đãi và không kéo dài thời hạn. Lần gia hạn mới dùng liên hệ mới đã xác nhận.

## 2. Nguyên tắc bắt buộc

1. Không coi việc nhập đúng định dạng là đã xác nhận quyền sở hữu.
2. Email mới chỉ có hiệu lực sau khi người dùng mở thư xác nhận.
3. Số điện thoại mới chỉ có hiệu lực sau khi người dùng nhập đúng mã SMS.
4. Thông tin cũ tiếp tục hoạt động cho tới khi thông tin mới được xác nhận; không
   để tài khoản rơi vào trạng thái không có cách đăng nhập hoặc nhận cảnh báo.
5. Mỗi email và mỗi số điện thoại đã xác nhận chỉ thuộc một tài khoản tại cùng
   một thời điểm.
6. Không ghi email, số điện thoại hoặc mã xác nhận vào log, báo lỗi ứng dụng,
   danh sách Bạn bè hoặc bộ nhớ ngoại tuyến của Bạn bè.
7. Mọi nút hiển thị liên hệ mặc định tắt và chỉ bật được sau khi liên hệ tương
   ứng đã xác nhận.

## 3. Luồng đăng ký tối giản

1. Người dùng nhập email, mật khẩu và tên.
2. Ứng dụng gửi thư xác nhận; có nút **Gửi lại thư xác nhận** với thời gian chờ.
3. Sau khi email được xác nhận, người dùng chọn quốc gia và nhập số điện thoại.
4. Ứng dụng tự ghép mã quốc gia, hiển thị lại số đã chuẩn hóa và gửi mã SMS.
5. Người dùng nhập mã sáu số. Mã có thời hạn, giới hạn số lần nhập sai và số lần
   gửi lại.
6. Người dùng hoàn thiện username, ngôn ngữ và các thông tin học tập.
7. Email và số điện thoại đều ở trạng thái **Ẩn với bạn bè** khi vào ứng dụng.

Người dùng chưa xác nhận đủ email và số điện thoại không được hoàn tất đăng ký
hoặc dùng tài nguyên có chi phí. Trạng thái chờ phải cho phép đăng xuất, gửi lại
mã và đổi email/số đã nhập sai.

## 4. Đổi email

1. Người dùng nhập lại mật khẩu hiện tại.
2. Nhập email mới và nhận thư xác nhận tại email mới.
3. Email cũ vẫn là email đăng nhập cho tới khi email mới được xác nhận.
4. Sau khi xác nhận thành công, hệ thống đổi sang email mới và gửi thông báo tới
   email cũ.
5. Quyền hiển thị email tự trở về **Ẩn** sau mỗi lần đổi; người dùng phải chủ
   động bật lại.
6. Đổi email không cấp lại ưu đãi và không thay đổi gói đang còn hạn.

## 5. Đổi số điện thoại

1. Người dùng xác nhận lại tài khoản bằng mật khẩu hiện tại.
2. Chọn quốc gia, nhập số mới và nhận mã SMS tại số mới.
3. Số cũ vẫn gắn với tài khoản cho tới khi số mới được xác nhận thành công.
4. Sau khi xác nhận, hệ thống đổi số, gửi cảnh báo qua email và đưa quyền hiển
   thị số điện thoại về **Ẩn**.
5. Đổi số không cấp lại ưu đãi và không thay đổi gói đang còn hạn.

## 6. Quyền hiển thị cho bạn bè

Cài đặt có hai công tắc độc lập:

- **Cho phép bạn bè xem email** — mặc định tắt.
- **Cho phép bạn bè xem số điện thoại** — mặc định tắt.

Quy tắc đọc:

- Chỉ hai tài khoản đang là bạn bè đã chấp nhận mới đọc được liên hệ đã bật.
- Người lạ, lời mời chờ, tài khoản bị từ chối hoặc quan hệ đã hủy đều không đọc
  được.
- Tắt công tắc hoặc hủy kết bạn có hiệu lực ngay cho lần đọc tiếp theo.
- Liên hệ không xuất hiện trong kết quả tìm bạn, bảng xếp hạng hoặc thông báo.
- Ứng dụng chỉ tải liên hệ khi mở hồ sơ của một người bạn; không tải hàng loạt và
  không lưu vào cache Bạn bè.

## 7. Gói dịch vụ và ưu đãi

### Gói đang còn hạn

- Gói gắn với tài khoản và ngày hết hạn, không gắn quyền sử dụng trực tiếp vào
  chuỗi email hoặc số điện thoại.
- Khi mua/đăng ký gói, lưu dấu email và số điện thoại đã xác nhận tại thời điểm
  đó trong vùng dữ liệu riêng để đối chiếu, không hiển thị công khai.
- Nếu đổi liên hệ trong lúc gói còn hạn, quyền lợi và ngày hết hạn giữ nguyên.
- Lần gia hạn sau dùng email và số điện thoại mới đã xác nhận.

### Chống nhận ưu đãi lặp lại

- Một tài khoản không nhận lại ưu đãi chỉ vì đã đổi email hoặc số điện thoại.
- Email/SĐT mới từng nhận cùng ưu đãi ở tài khoản khác không được nhận lại.
- Lưu lịch sử lần nhận ưu đãi theo tài khoản và dấu liên hệ đã xác nhận; không
  dựa vào dữ liệu trên thiết bị của người dùng.
- Số được nhà mạng cấp lại cho người khác phải có đường hỗ trợ xem xét thủ công;
  không khóa vĩnh viễn người dùng mới chỉ dựa trên lịch sử số điện thoại.

Hệ thống hiện chưa có sổ ưu đãi. Không được suy diễn bảng `subscriptions` hiện
có đã giải quyết việc chống nhận lặp lại.

## 8. Hạn chế số ảo và hành vi tạo hàng loạt

- Cho phép mọi quốc gia; khả năng gửi thực tế phụ thuộc vùng mà nhà cung cấp SMS
  hỗ trợ và quy định của từng nước.
- Kiểm tra loại số nếu nhà cung cấp có dữ liệu, nhưng không coi kết quả này là
  bằng chứng duy nhất vì có thể chặn nhầm số thật.
- Giới hạn gửi mã theo số điện thoại, tài khoản, thiết bị và mạng trong một
  khoảng thời gian.
- Thêm bước kiểm tra chống máy tự động khi hành vi bất thường.
- Giới hạn tài nguyên tốn phí cho tài khoản mới cho tới khi email và số điện
  thoại đều được xác nhận.
- Không tiết lộ email/SĐT đã tồn tại hay lý do chi tiết khiến một số bị từ chối.

## 9. Thay đổi dữ liệu dự kiến

Đây là kế hoạch, chưa phải tên bảng/cột cuối cùng:

- Chuyển số điện thoại hồ sơ từ mẫu Việt Nam `0xxxxxxxxx` sang dạng có mã quốc
  gia, ví dụ `+84987654321`.
- Kiểm kê và xử lý dữ liệu cũ trước khi thay ràng buộc; không tự đoán quốc gia
  nếu dữ liệu không đủ rõ.
- Nguồn xác nhận email/SĐT phải lấy từ hệ thống đăng nhập, không cho ứng dụng tự
  đánh dấu đã xác nhận.
- Thêm cài đặt riêng cho `hiển thị email với bạn bè` và `hiển thị SĐT với bạn
  bè`; không dùng lại cờ tìm kiếm email/SĐT vì hai ý nghĩa khác nhau.
- Thêm lịch sử thay đổi liên hệ, thời điểm xác nhận và liên hệ được dùng lúc bắt
  đầu/gia hạn gói.
- Thêm sổ nhận ưu đãi để chống nhận lại sau khi đổi liên hệ.
- Mọi dữ liệu liên hệ/lịch sử nằm trong vùng riêng; ứng dụng chỉ đọc qua thao
  tác được kiểm tra quyền ở máy chủ.

## 10. Các giai đoạn triển khai

### A0 — Chốt nhà cung cấp và hợp đồng dữ liệu

**Làm:** chọn dịch vụ SMS có thể gửi quốc tế, thống kê quốc gia thực sự hỗ trợ,
chi phí, giới hạn và cách nhận biết số tạm thời. Chốt thời hạn mã, thời gian chờ
gửi lại, số lần nhập sai và thời gian giữ lịch sử chống lạm dụng.

**Hoàn thành khi:** có tài khoản Staging, khóa truy cập lưu ngoài repo, bảng chi
phí/quốc gia và quy định giữ dữ liệu được duyệt.

### A1 — Migration số điện thoại quốc tế và dữ liệu riêng

**Làm:** sao lưu/kiểm kê số cũ, thêm cấu trúc số quốc tế, lịch sử liên hệ, quyền
hiển thị và sổ ưu đãi; giữ tương thích trong thời gian chuyển đổi.

**Hoàn thành khi:** migration chạy lại an toàn; số trùng/sai không bị sửa âm
thầm; người lạ không đọc được liên hệ; Production chưa bị thay đổi.

### A2 — Xác nhận email và đổi email

**Làm:** sửa nhãn đăng nhập chỉ còn **Email**, thêm gửi lại thư, khóa tài nguyên
trước xác nhận, luồng đổi email và thông báo email cũ.

**Hoàn thành khi:** email chưa xác nhận không vượt qua được bằng sửa ứng dụng;
email cũ còn hiệu lực đến khi email mới xác nhận; lỗi và gửi lại có giới hạn.

### A3 — SMS quốc tế và đổi số điện thoại

**Làm:** thay bước SĐT Việt Nam bằng chọn quốc gia + số; gửi/xác nhận SMS; nối
việc hoàn tất hồ sơ với trạng thái xác nhận; thêm đổi số.

**Hoàn thành khi:** số mới chỉ có hiệu lực sau mã đúng; mã sai/hết hạn/gửi dồn bị
chặn; đổi tài khoản giữa lúc xác nhận không áp dụng kết quả cho tài khoản cũ.

### A4 — Hiển thị liên hệ cho bạn bè

**Làm:** hai công tắc mặc định tắt và màn hồ sơ bạn bè chỉ đọc liên hệ được chủ
tài khoản cho phép.

**Hoàn thành khi:** chỉ bạn bè đã chấp nhận xem được; tắt quyền/hủy kết bạn có
hiệu lực ngay; tìm kiếm Bạn bè vẫn chỉ dùng username.

### A5 — Gói và ưu đãi khi đổi liên hệ

**Làm:** chụp dấu liên hệ lúc bắt đầu/gia hạn gói; giữ gói hiện tại khi đổi; sổ
ưu đãi từ chối nhận lại theo tài khoản và lịch sử liên hệ.

**Hoàn thành khi:** ma trận đổi email, đổi SĐT, đổi cả hai, hết hạn, gia hạn và
số được cấp lại đều có kiểm tra tự động; không mất gói hoặc nhận lặp ưu đãi.

### A6 — Exact-Staging và rollout

**Làm:** backup, dry-run, apply sau phê duyệt, thử email thật và SMS thật ở nhiều
quốc gia, hai tài khoản/bạn bè/người lạ, đổi liên hệ, gói còn hạn và cleanup.

**Hoàn thành khi:** Android/iOS/Web pass; không lộ liên hệ; không ghi Production
trước gate riêng; có cách tắt luồng mới nếu SMS/email provider gặp sự cố.

## 11. Tài khoản cũ

- Tài khoản có gói còn hạn tiếp tục dùng tới ngày hết hạn dù chưa hoàn tất đổi
  liên hệ; phải xác nhận liên hệ hiện hành trước lần gia hạn mới.
- Tài khoản miễn phí được yêu cầu xác nhận email/SĐT ở lần đăng nhập kế tiếp
  trước khi dùng tài nguyên có chi phí.
- Không tự bật quyền hiển thị cho bất kỳ tài khoản cũ nào.
- Dữ liệu SĐT Việt Nam cũ chỉ chuyển sang `+84` khi vượt qua kiểm tra định dạng;
  bản ghi không rõ ràng phải đưa vào danh sách xử lý, không đoán.

## 12. Việc cần người vận hành cung cấp

- Chọn nhà cung cấp SMS quốc tế và cấp khóa Staging qua kho bí mật.
- Duyệt ngân sách, quốc gia không thể gửi và cách hỗ trợ người dùng ở vùng đó.
- Chốt thời gian giữ lịch sử email/SĐT phục vụ chống lạm dụng.
- Chốt nội dung điều khoản riêng tư về lưu liên hệ, hiển thị cho bạn bè và lịch
  sử chống nhận ưu đãi lặp lại.
- Phê duyệt riêng trước mọi migration, bật SMS thật, gửi email thật hoặc deploy.
