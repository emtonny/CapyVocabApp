Giữ nguyên bố cục trước, nhưng lần này mỗi mục sẽ nói rõ **đặc điểm cụ thể của style NeoBrutal EdTech khi áp dụng cho app mobile**.

**Mục 1: Visual Identity**
Có tác dụng là xác định **cảm giác tổng thể của toàn bộ ứng dụng**.

Đặc điểm của style:

* mạnh, rõ, có cá tính
* trẻ và hiện đại
* thân thiện hơn Brutalism truyền thống
* mang cảm giác EdTech / Creator
* không corporate
* không tối giản lạnh
* ưu tiên bố cục sạch nhưng visual nổi bật
* cân bằng khoảng **65% structured / 35% playful**  

**Hiểu đơn giản:** app phải nhìn **vui nhưng không trẻ con, mạnh nhưng không thô, có cá tính nhưng vẫn dễ dùng**.

---

**Mục 2: Color System**
Có tác dụng là quy định **bảng màu thống nhất cho toàn bộ app**.

Đặc điểm của style:

* nền chủ đạo: Cream `#FAF6EA`
* chữ/viền chính: Black `#1A1A1A`
* accent:

  * Yellow `#FFD36B`
  * Coral `#F8785B`
  * Mint `#88C4A0`
  * Blue `#5CA6E7`
  * Pink `#EAB0C1`
  * Lavender `#B5A0E1`
* màu phẳng, bão hòa vừa phải
* mỗi màn hình nên có một màu chủ đạo
* tỉ lệ tham khảo: **60% base / 30% secondary / 10% accent**
* không gradient
* không glow
* không glossy
* hạn chế nền trắng thuần 

**Hiểu đơn giản:** nền nhẹ + màu pastel nổi + đen mạnh để tạo tương phản.

---

**Mục 3: Typography System**
Có tác dụng là tạo **thứ bậc và khả năng đọc rõ ràng**.

Đặc điểm của style:

* dùng sans-serif
* ưu tiên **Inter**
* chữ tiêu đề rất đậm
* heading có scale lớn rõ rệt so với body
* ưu tiên căn trái
* headline ngắn
* khoảng cách chữ hơi chặt với heading lớn
* label nhỏ thường viết uppercase
* không dùng quá nhiều font
* tối đa khoảng 1 font chính cho toàn app 

Ví dụ hierarchy:

* Display / H1: rất lớn, weight 800–900
* H2: lớn, weight 750–850
* H3: medium-bold
* Body: regular
* Label: nhỏ, đậm, uppercase

**Hiểu đơn giản:** chữ phải tạo cảm giác **editorial, mạnh và rõ**, không mềm hoặc trang trí quá nhiều.

---

**Mục 4: Shape, Border & Shadow**
Có tác dụng là tạo **dấu hiệu nhận diện Neo-Brutal rõ nhất**.

Đặc điểm của style:

**Border**

* viền đen
* dày rõ
* card khoảng 3–4 px
* component nhỏ khoảng 2–3 px

**Shadow**

* hard shadow
* đổ xuống-phải
* offset khoảng 5–10 px
* blur = 0
* màu đen

**Radius**

* card lớn: khoảng 18–28 px
* card nhỏ: khoảng 16–22 px
* pill: bo tròn hoàn toàn
* highlight chữ: gần vuông

Không dùng:

* shadow mờ
* glassmorphism
* gradient border
* hiệu ứng nổi 3D bóng bẩy 

**Hiểu đơn giản:** component nhìn giống **một khối giấy/card màu có viền đen và một lớp bóng đen bị lệch phía sau**.

---

**Mục 5: Spacing & Layout**
Có tác dụng là giữ cho style mạnh nhưng **không bị rối**.

Đặc điểm của style:

* sử dụng spacing theo hệ 8pt
* ví dụ: `8 / 16 / 24 / 32 / 40 / 48 / 64 / 80`
* padding trong card khá rộng
* ưu tiên bố cục căn trái
* nhiều negative space
* khoảng 20–35% không gian có thể để trống
* bố cục bất đối xứng nhưng cân bằng
* các thành phần phải có alignment rõ
* không đặt mọi thứ vào giữa màn hình 

**Hiểu đơn giản:** visual có thể vui và mạnh, nhưng layout bên dưới phải **rất kỷ luật**.

---

**Mục 6: Component System**
Có tác dụng là tạo **ngôn ngữ UI thống nhất trong toàn app**.

Đặc điểm style của component:

* **Button:** màu pastel hoặc đen, viền đen, chữ đậm, shadow cứng
* **Card:** bo góc lớn, viền đen, màu cream/pastel, hard shadow
* **Chip / Pill:** bo tròn hoàn toàn, chữ nhỏ đậm
* **Badge:** thường là vòng tròn màu + outline đen
* **Input:** nền sáng, border đen rõ, radius đồng nhất
* **Tab:** trạng thái selected dùng màu accent mạnh
* **Modal:** giống một card lớn nổi bật
* **Navigation:** đơn giản, icon nét dày, selected state rõ

Tinh thần của component gốc là sử dụng một thư viện thành phần nhất quán thay vì tạo UI primitive mới tùy ý. 

**Hiểu đơn giản:** tất cả component phải có cảm giác **cùng được sinh ra từ một bộ LEGO**.

---

**Mục 7: Interaction & State System**
Có tác dụng là xác định **component thay đổi thế nào khi người dùng thao tác**.

Đây là phần mở rộng cần thiết khi chuyển style từ slide sang app mobile.

Đặc điểm nên giữ theo style:

* **Default:** border + hard shadow đầy đủ
* **Pressed:** shadow giảm hoặc biến mất, component dịch nhẹ xuống-phải
* **Selected:** đổi sang màu accent mạnh
* **Focus:** border rõ hơn hoặc accent outline
* **Disabled:** giảm contrast nhưng vẫn giữ hình dạng
* **Error:** coral/red accent
* **Success:** mint/green accent
* **Loading:** ưu tiên animation đơn giản, không dùng glow

**Hiểu đơn giản:** interaction cũng nên mang tính **vật lý** — giống như người dùng thực sự đang nhấn một khối UI xuống.

---

**Mục 8: Icon, Illustration & Decoration**
Có tác dụng là giữ **hình ảnh phụ trợ đồng nhất với UI**.

Đặc điểm của style:

* icon đơn giản
* line icon
* nét tương đối dày
* hình học rõ
* illustration phẳng
* có thể sử dụng:

  * circle
  * rounded rectangle
  * outlined shapes
  * dot pattern
* Memphis geometry chỉ nên xuất hiện vừa phải
* khoảng 1–3 decoration chính trên một khu vực
* không icon 3D glossy
* không trộn nhiều icon pack 

**Hiểu đơn giản:** decoration phải tạo cá tính, **không được giành sự chú ý khỏi chức năng chính**.

---

**Mục 9: Screen Composition**
Có tác dụng là quy định **cách xây màn hình từ các component**.

Đặc điểm của style:

* một màn hình nên có một focal point rõ
* title/headline thường chiếm ưu thế ở phía trên
* nội dung được chia thành card/module
* tránh paragraph dài
* ưu tiên nhóm thông tin thành block
* danh sách nên được biến thành row/card thay vì bullet thuần
* có thể dùng nhiều màu card để phân loại thông tin
* không nhồi quá nhiều loại UI vào cùng một màn hình

Tinh thần gốc của tài liệu là **one slide = one main idea**; khi chuyển sang app, có thể hiểu thành **one screen = one primary task / one dominant purpose**. 

**Hiểu đơn giản:** mỗi màn hình phải có một việc chính rõ ràng, không biến một screen thành dashboard chứa mọi thứ.

---

**Mục 10: UX & Accessibility Rules**
Có tác dụng là đảm bảo style mạnh nhưng **không phá usability**.

Đặc điểm cần giữ:

* contrast cao
* body text luôn đủ lớn
* không giảm font để nhét thêm nội dung
* màu pastel sáng dùng chữ đen
* màu tối dùng chữ cream/white
* button và touch target đủ lớn
* trạng thái selected/error/disabled phải dễ phân biệt
* decoration không được che nội dung
* text không va vào shadow hoặc border
* tránh quá nhiều màu trên cùng màn hình

Tài liệu gốc cũng nhấn mạnh readability, contrast, negative space và không được ép chữ nhỏ để chứa nội dung.  

**Hiểu đơn giản:** **style phải phục vụ UX**, không được hy sinh khả năng sử dụng chỉ để trông “Neo-Brutal”.

---

**Mục 11: Consistency & Quality Control**
Có tác dụng là đảm bảo **toàn bộ app nhìn như một sản phẩm duy nhất**.

Đặc điểm cần kiểm tra:

* cùng font
* cùng palette
* cùng radius
* cùng border thickness
* cùng shadow direction
* cùng spacing scale
* cùng icon style
* cùng logic màu trạng thái
* cùng cách thiết kế button/card/input
* không màn hình nào tự dùng gradient, glassmorphism hoặc style khác

Các lỗi làm style bị phá:

* gradient
* shadow blur
* nhiều font
* contrast yếu
* radius không đồng nhất
* quá nhiều màu
* layout quá chật
* quá nhiều decoration
* cảm giác corporate/generic 

**Hiểu đơn giản:** dù app có 5 hay 50 màn hình, người dùng vẫn phải cảm thấy **đây là cùng một sản phẩm**.

---

## Cốt lõi style của toàn dự án

Có thể cô đọng NeoBrutal EdTech mobile thành:

> **Bold Typography + Thick Black Borders + Hard Offset Shadows + Saturated Pastels + Rounded Cards + Strong Grid + Generous Whitespace + Playful Geometry**

Về cảm giác:

> **Neo-Brutal đủ mạnh để có cá tính, Swiss đủ kỷ luật để sạch, EdTech đủ thân thiện để dễ sử dụng.**

Về nguyên tắc thiết kế:

> **Structured first → Playful second → Decoration last.**

Đây là phần cần giữ ổn định nhất nếu muốn toàn bộ app có đúng visual family của tài liệu gốc.
