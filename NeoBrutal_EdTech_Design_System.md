NeoBrutal EdTech — App Design System

Style blend: Neo‑Brutalism 55% · Swiss / International Style 25% · Memphis 10% · Modern EdTech / Creator Economy 10%

1. Design Direction

Phong cách của app phải tạo cảm giác:

Bold · Friendly · Modern · Educational · Structured · Editorial · Approachable · Creator-led

Công thức tổng thể:

Neo‑Brutal visual + Swiss structure + Memphis personality + EdTech usability

Vai trò của từng lớp phong cách:

Neo‑Brutalism 55% → cá tính thương hiệu: viền đen, shadow cứng, màu phẳng, card rõ khối.

Swiss 25% → giữ UI gọn và chuyên nghiệp: grid, căn hàng, typography, hierarchy, whitespace.

Memphis 10% → thêm năng lượng và khả năng nhận diện bằng hình học vui nhộn.

Modern EdTech 10% → tạo cảm giác học tập hiện đại qua progress, streak, badge, template, personalization và feedback.

Shape Direction

Ngôn ngữ hình học xuyên suốt app:

Square / Rectangle  → mặc định
Slight Radius       → làm mềm vừa đủ
Pill                → chỉ dành cho tag/chip/status
Hard Shadow         → tạo độ nổi và chiều sâu

Ưu tiên cảm giác boxy và chắc khối hơn cảm giác mềm, tròn, “cute”.

Nguyên tắc cân bằng

Giữ tổng thể khoảng:

65% clean / structured

35% playful / brutalist

Neo‑Brutalism phải tạo cá tính, không được làm UI trở nên thô, nặng hoặc hỗn loạn.

2. Design DNA

Các yếu tố cốt lõi phải xuất hiện xuyên suốt hệ thống:

Typography sans-serif đậm, phân cấp rõ.

Viền đen rõ trên component chính.

Hard offset shadow, không blur.

Màu pastel bão hòa, dạng flat.

Cream / off-white là nền trung tính chính.

Card và button ưu tiên hình vuông / chữ nhật, chỉ bo góc nhẹ.

Box shadow cứng, lệch rõ và đủ dày để tạo cảm giác khối nổi.

Grid và alignment theo tinh thần Swiss.

Semantic highlight: màu dùng để nhấn thông tin có ý nghĩa.

Nếu nhiều yếu tố trên bị loại bỏ cùng lúc, giao diện sẽ mất chất NeoBrutal EdTech.

3. Visual Hierarchy

Mỗi màn hình có 4 tầng ưu tiên:

Primary focal point — tiêu đề / nhiệm vụ chính.

Interactive content — card, CTA, lựa chọn chính.

Supporting information — mô tả, caption, helper text.

Metadata / decoration — badge nhỏ, Memphis shape, thông tin phụ.

Quy tắc

Một màn hình chỉ nên có 1 mục tiêu chính.

Một màn hình chỉ nên có 1 CTA nổi trội nhất.

Không để tất cả component cùng “gào”.

Decoration không được cạnh tranh với nội dung học tập.

4. Color System

4.1 Core Palette

INK_BLACK      #1A1A1A
CREAM          #FAF6EA
WHITE_SOFT     #FFFDF7

YELLOW         #FFD36B
CORAL          #F8785B
MINT           #88C4A0
BLUE           #5CA6E7
PINK           #EAB0C1
LAVENDER       #B5A0E1
DARK_GREEN     #31483D

Có thể tinh chỉnh nhẹ cho khả năng hiển thị trên Android/iOS, nhưng quan hệ tương phản phải giữ nguyên.

4.2 Color Roles

Gợi ý semantic role:

Background          CREAM / WHITE_SOFT
Primary Ink         INK_BLACK

Primary CTA         YELLOW
Success             MINT / DARK_GREEN
Info                BLUE
Creative / Custom   LAVENDER
Warning / Attention CORAL
Soft Accent         PINK

4.3 Color Composition

Mỗi màn hình nên gần với:

60% Base
30% Secondary
10% Accent

Không chia đều tất cả màu pastel.

Mỗi màn hình cần có một màu dominant.

4.4 Contrast

Dùng chữ đen trên:

cream

yellow

mint

coral

blue

pink

lavender

Dùng chữ trắng/cream chủ yếu trên:

black

dark green

Không dùng

gradient làm visual chính

glassmorphism

neon glow

metallic

glossy effect

background xám corporate quá nhiều

5. Typography

5.1 Font

Ưu tiên:

Inter

Fallback / alternative:

Be Vietnam Pro
Manrope
Archivo
Plus Jakarta Sans
Geist Sans
Arial / sans-serif

Quy tắc

Toàn app ưu tiên 1 font family.

Tối đa 1 font accent nếu thật sự cần cho branding.

Typography là hero; icon và decoration chỉ hỗ trợ.

5.2 Mobile Type Scale

Display / Hero   30–36sp | 800–900
H1               26–30sp | 800
H2               22–26sp | 750–800
H3               18–22sp | 700–800
Body             14–16sp | 400–500
Small            12–13sp | 500–700
Eyebrow / Label  11–13sp | 700–800
Button           14–16sp | 700–800

Heading

Ngắn.

Trực tiếp.

Tối đa khoảng 2–3 dòng.

Ưu tiên căn trái.

Letter spacing có thể hơi âm với heading lớn.

Eyebrow / Small Label

Có thể uppercase:

HỌC HÔM NAY
MẪU NOTE
BƯỚC 01
THÀNH TỰU

Không dùng uppercase cho toàn bộ giao diện.

6. Semantic Text Highlight

Có thể dùng block màu hình chữ nhật để nhấn từ khóa.

Ví dụ:

Quét ảnh → học TỪ VỰNG

Trong đó TỪ VỰNG có background màu accent.

Quy tắc

Chỉ highlight thông tin có ý nghĩa.

Khoảng 15–25% headline là đủ.

Highlight thường vuông hoặc bo rất nhẹ.

Không highlight toàn bộ câu nếu không cần.

Không dùng highlight chỉ để “cho đẹp”.

7. Border System

Viền đen là signature element nhưng không áp dụng vô tội vạ.

Mobile Tokens

Primary Card      2.5–3px
Primary Button    2.5–3px
Secondary Card    2px
Input             2px
Pill / Badge      2px
Divider           1–1.5px

Default:

#1A1A1A

Nên có border

CTA

action card

selected template

modal quan trọng

challenge / achievement card

creator/custom component

Có thể giảm border

list row thông thường

metadata

secondary information

background container

Không biến “viền đen mọi thứ” thành quy tắc bắt buộc.

8. Shadow System

Shadow là một trong những signature mạnh nhất của hệ thống.

Mục tiêu là làm các box có cảm giác nổi thành khối, giống một mảnh giấy/card dày đặt trên nền.

Chỉ dùng hard offset shadow:

Không blur.

Không glow.

Không shadow mờ.

Shadow phải nhìn thấy rõ ngay cả trên màn hình nhỏ.

Hướng mặc định: bottom-right.

Mobile Tokens

Hero / Primary Box
x: +8–10px
y: +8–10px
blur: 0
spread: 0

Standard Card / Button
x: +6–8px
y: +6–8px
blur: 0

Secondary Box
x: +4–6px
y: +4–6px
blur: 0

Small Element
x: +2–4px
y: +2–4px
blur: 0

Shadow color mặc định:

#1A1A1A

Box Shadow Priority

Shadow mạnh nhất dành cho:

Primary CTA.

Action card.

Selected card.

Modal / bottom sheet quan trọng.

Achievement / challenge card.

Các row thông thường hoặc metadata có thể không cần shadow.

Pressed State

Khi nhấn:

component translate: +3–4px X/Y
shadow offset giảm tương ứng

Ví dụ:

Default:
box-shadow: 8px 8px 0 #1A1A1A

Pressed:
transform: translate(4px, 4px)
box-shadow: 4px 4px 0 #1A1A1A

Hiệu ứng này phải tạo cảm giác box được ấn xuống thật, không phải animation mềm.

9. Radius System

Ngôn ngữ hình khối chính:

Square-first / rectangular-first.

Card, button và box ưu tiên hình vuông hoặc chữ nhật, chỉ bo góc nhẹ để giữ cảm giác thân thiện mà không mất chất Neo‑Brutal.

Mobile Radius Tokens

Hero / Large Card   10–12px
Standard Card       8–10px
Small Card          6–8px
Button              8–10px
Input               8–10px
Modal / BottomSheet 10–14px
Text Highlight      0–3px
Pill / Tag          999px

Quy tắc hình khối

80–90% component chính dùng square / rectangular geometry.

Chỉ pill, tag, chip, status badge mới được bo tròn hoàn toàn.

Không dùng card bo 20–28px như phong cách soft SaaS.

Không biến button thành capsule nếu không có lý do chức năng.

Radius giữa các component phải có hệ thống, không thay đổi ngẫu nhiên.

Visual Target

Đúng:

┌──────────────┐
│              │
│    CARD      │
│              │
└──────────────┘
      ████████  ← hard shadow lệch

Tránh:

╭──────────────╮
│  soft card   │
╰──────────────╯

Mục tiêu là boxy, chunky, rõ cạnh, nhưng vẫn đủ thân thiện cho EdTech.

10. Spacing System

Dùng hệ thống theo bội của 4, ưu tiên nhịp 8pt:

4
8
12
16
20
24
32
40
48
64

Recommended Mobile Spacing

Screen horizontal padding   20–24
Section gap                 24–32
Large card padding          20–24
Standard card padding       16–20
Small card padding          12–16
Icon → Text                 8–12
Title → Supporting text     6–10
CTA vertical padding        14–18

Không sử dụng spacing ngẫu nhiên nếu không có lý do.

11. Swiss Grid & Alignment

Swiss Style là hệ thống kiểm soát độ “ồn” của Neo‑Brutalism.

Quy tắc

Dùng grid nhất quán.

Edge của card nên thẳng hàng.

Ưu tiên left alignment.

Giữ baseline rõ ràng.

Không center toàn màn hình chỉ vì trông “cân”.

Center alignment phù hợp cho:

icon trong button/card

số trong badge

compact empty state

badge / chip ngắn

một CTA riêng biệt

Không phù hợp

đoạn body dài

danh sách option

settings

form

màn hình học có nhiều thông tin

12. Negative Space

Whitespace là một phần của design.

Mục tiêu:

khoảng 20–35% màn hình có không gian thở khi nội dung cho phép.

không cố lấp kín màn hình.

tránh xếp CTA, card, decoration sát nhau.

Một màn hình tốt thường có:

1 Hero / Header Area
+
1 Main Content System
+
1 Primary Action

13. Core Component Library

Hạn chế tự tạo component mới nếu component hiện có đã giải quyết được vấn đề.

13.1 Primary Button

Accent background
Black border
**Strong hard shadow**
**Square / rectangular shape with slight radius**
Bold label
Optional icon

Ví dụ:

[ 📷  QUÉT ẢNH ]

State

Default → hard shadow đầy đủ.

Pressed → translate xuống/phải.

Disabled → giảm saturation + shadow nhẹ/không shadow.

Loading → giữ width ổn định, dùng spinner đơn giản.

Success → check icon + semantic green/mint.

13.2 Secondary Button

Cream / white background
Black border
Shadow nhỏ hơn Primary nhưng vẫn rõ
Square / rectangular shape
Black text

Không cạnh tranh thị giác với Primary CTA.

13.3 Action Card

Dùng cho:

Chụp ảnh.

Tải ảnh.

Ôn từ.

Tạo bộ từ.

Challenge.

Cấu trúc:

Icon
Title
Short description
Optional indicator

Action Card có thể dùng màu pastel dominant. Hình khối ưu tiên chữ nhật rõ cạnh, radius nhẹ và shadow đậm.

13.4 Information Card

Cream / soft white
Black border khi cần
Square / rectangular
Slight radius
Hard shadow rõ

Nội dung lý tưởng:

Label / Icon
Title
1 đoạn hỗ trợ ngắn

Tránh paragraph dài.

13.5 Note Template Card

Dùng cho:

Mặc định

Tối giản

Tự thiết kế

Template mới

Selected state phải có ít nhất 2 tín hiệu và nên làm box nổi bật hơn bằng shadow:

Strong border
+
Check icon
+
Optional accent background

Không chỉ dùng màu để biểu thị selected.

13.6 Pill / Tag

Dùng cho:

category

level

language

streak

trạng thái

filter

Dark Pill

Background: black
Text: cream
Radius: full

Colored Pill

Accent background
Black border
Black text

13.7 Number Badge

Dùng cho:

onboarding

learning process

lesson steps

challenge sequence

Circle
Accent fill
Black border
Bold number

13.8 Input

White / cream background
2px black border
8–10px radius
Rectangular shape
Clear label

Focus:

black border
+
small accent offset shadow / highlight

Error:

coral border/accent
+
clear helper text

Không chỉ đổi màu mà không có text giải thích.

13.9 Progress

Progress phải trực quan và dễ đọc.

Có thể dùng:

████████░░  12 / 15

Hoặc thanh progress Neo‑Brutal:

black outline

flat fill

không gradient

percentage / count rõ

13.10 Achievement / Metric Card

Dùng cho:

streak

số từ đã học

XP

level

completion rate

Cấu trúc:

Large metric
Small label
Optional icon

Ví dụ:

🔥 7
ngày liên tục

14. Icon System

Icon nên:

simple

outline hoặc solid rõ ràng

stroke tương đối dày

ít chi tiết

cùng một icon family

Ưu tiên:

camera

image

pin

palette

book

fire

star

trophy

check

edit

audio

Tránh

glossy 3D icon

icon photorealistic

icon gradient

trộn nhiều pack có stroke khác nhau

icon lớn hơn nội dung mà nó hỗ trợ

15. Memphis Geometry

Memphis chỉ là gia vị.

Có thể sử dụng:

dot pattern

+

×

circle

square

zigzag

outlined shape

mini sticker

Mức sử dụng

Khoảng:

1–3 decorative groups / screen

Có thể tăng nhẹ ở:

onboarding

empty state

celebration

achievement

marketing surface

Giảm mạnh ở:

form

settings

payment

permission

dense learning screens

Decoration phải giúp cân bố cục, không được rải ngẫu nhiên.

16. Background Texture

Có thể dùng dot-grid rất nhẹ.

Opacity: 5–10%
Spacing: 16–24px

Chỉ dùng khi background quá trống.

Không để pattern làm giảm readability.

17. Illustration & Mascot

Mascot / illustration nên:

flat hoặc sticker-like

silhouette rõ

đơn giản

màu thống nhất với palette

friendly

dễ nhận diện ở kích thước nhỏ

Dùng mascot khi

onboarding

celebration

empty state

learning encouragement

daily goal

feature introduction

Không dùng mascot để

lấp khoảng trống vô nghĩa

xuất hiện ở mọi card

thay thế icon chức năng

cạnh tranh với nội dung chính

18. Motion & Interaction

Motion mang cảm giác:

snap · pop · small bounce

Timing:

100–250ms

Phù hợp:

button press

card select

check pop

XP increment

progress update

sticker bounce nhẹ

modal entrance

swipe transition

Tránh

animation dài

elastic quá mạnh

floating liên tục

luxury easing quá mềm

glow animation

Motion phải phản hồi hành động, không chỉ để trang trí.

19. Modern EdTech Layer

EdTech 10% nằm chủ yếu ở trải nghiệm, không phải chỉ màu sắc.

Các pattern phù hợp:

Daily Goal

Learning Progress

Streak

XP

Level

Badge

Mini Challenge

Smart Review

Saved Vocabulary

Template

Custom Creator Mode

Achievement feedback

Nguyên tắc:

Learning first. Gamification second.

Gamification phải hỗ trợ thói quen học, không biến app thành game thuần túy.

20. Tone of Voice

Copy nên:

thân thiện

tự tin

ngắn

dễ hiểu

practical

beginner-friendly

Ví dụ tốt:

Quét một bức ảnh.
Học những từ bạn thật sự nhìn thấy.

Bạn còn 3 từ để hoàn thành mục tiêu hôm nay.

Tránh:

Tiến hành khởi tạo quy trình nhận diện từ vựng bằng trí tuệ nhân tạo.

Ưu tiên ngôn ngữ tự nhiên hơn:

Quét ảnh để tìm từ mới.

21. Content Density

UI không được text-heavy.

Card title

2–6 từ

Card description

1–2 dòng

Helper text

Càng ngắn càng tốt nhưng không được làm mất nghĩa.

Nếu content không vừa:

rút gọn wording

chia section

đổi layout

progressive disclosure

đưa detail sang màn hình / bottom sheet khác

Không giảm font xuống quá nhỏ chỉ để nhét nội dung.

22. One Screen = One Main Job

Mapping gợi ý:

Scan screen
→ Quét hoặc tải ảnh

Scan result
→ Hiểu và chọn từ

Vocabulary detail
→ Học 1 từ

Review screen
→ Trả lời / ghi nhớ

Progress screen
→ Xem tiến độ

Template screen
→ Chọn style note

Custom template
→ Tạo style riêng

Không gom quá nhiều job chính vào cùng một màn hình.

23. App-specific Visual Patterns

23.1 Scan Vocabulary Screen

Ưu tiên:

Title
Short guidance

[ CHỤP ẢNH ] [ TẢI ẢNH ]

Template selector

Primary CTA / Next action

Hai action đầu có thể là large colored action cards.

Decoration chỉ nằm ở vùng trống.

23.2 Vocabulary Note

Note nên giống sticker/card có thể nhận diện ngay.

Ví dụ:

APPLE
/ˈæp.əl/

quả táo

Hierarchy:

Word
Pronunciation
Meaning
Optional image/context

Không để quá nhiều metadata trên mặt note chính.

23.3 Template Picker

Template card phải cho thấy personality khác nhau:

Mặc định
Tối giản
Sticker
Notebook
Tự thiết kế

Selected state rõ bằng border + check.

Không làm mỗi template thành một visual language hoàn toàn khác app.

23.4 Learning Progress

Hiển thị trực tiếp:

12 / 15 từ hôm nay

với progress bar hoặc metric card.

Ưu tiên số lớn, label nhỏ.

23.5 Achievement

Ví dụ:

🔥 7 ngày liên tục
⭐ 100 từ đã học
🏆 Level 5

Achievement có thể “ồn” hơn UI bình thường một chút.

24. State Design

Mọi component tương tác quan trọng cần có:

Default
Pressed
Selected
Focused
Disabled
Loading
Success
Error

Neo‑Brutal visual không được làm mất khả năng phân biệt state.

Selected

Không chỉ dựa vào màu.

Disabled

Không chỉ giảm opacity đến mức unreadable.

Loading

Không thay đổi layout gây nhảy màn hình.

Error

Thông báo rõ lý do và cách sửa.

25. Accessibility & Readability

Phong cách mạnh không được đánh đổi usability.

Bắt buộc

text/background đủ tương phản

tap target tối thiểu hợp lý cho mobile

selected state không dựa vào màu duy nhất

body text đủ lớn

decoration không che content

icon quan trọng có label hoặc semantics

không dùng animation quá nhiều ở task lặp lại

Neo‑Brutalism là visual language, không phải lý do để giảm usability.

26. Anti-Corporate Rules

Không dùng:

corporate blue gradient

glassmorphism

blurred shadows

quá nhiều grey

center alignment khắp nơi

generic dashboard card grid

tiny sharp-corner boxes

stock-business aesthetic

default-looking UI kit không chỉnh sửa

Mục tiêu là:

creator-led EdTech, không phải SaaS dashboard doanh nghiệp.

27. Anti-Template Rules

Không tạo UI kiểu:

Title
+
6 dòng text
+
random icon

Thay vào đó:

action → action card

progress → metric/progress component

process → numbered steps

category → color-coded card/tag

comparison → split layout

important phrase → semantic highlight

achievement → metric card

Nội dung quyết định component.

Không chọn component chỉ vì nó “đẹp”.

28. Signature Elements

Hầu hết các màn hình chủ đạo nên có 1–2 signature elements, ví dụ:

black pill label

strong hard-shadow rectangular card

semantic keyword highlight

number circle

pastel module card

Neo‑Brutal CTA

Không cần đặt tất cả signature vào cùng một màn hình.

29. Design Failure Conditions

Một màn hình bị coi là lệch style nếu:

dùng gradient làm visual chính

dùng soft blurred shadow

dùng nhiều font không liên quan

body text quá nhỏ

mọi thứ đều center

quá nhiều decoration

quá nhiều màu cùng lúc

border/radius không nhất quán

card/button bị bo quá tròn, mất chất boxy

UI quá corporate

hierarchy yếu

layout quá chật

Memphis shape xuất hiện vô nghĩa

mọi component đều có shadow lớn như nhau; shadow phải có hierarchy

selected state khó nhận ra

visual “ồn” hơn nội dung học

30. Screen Design Workflow

Mỗi khi thiết kế màn hình mới:

Step 1 — Xác định job chính

Ví dụ:

Scan
Select
Learn
Review
Create
Track

Step 2 — Chọn focal point

Đâu là thứ user phải nhìn thấy đầu tiên?

Step 3 — Chọn dominant color

Chỉ 1 màu accent chính.

Step 4 — Chọn component theo semantics

Card / CTA / metric / row / template / progress.

Step 5 — Áp tokens

typography

color

border

radius

shadow

spacing

Step 6 — Kiểm tra hierarchy

Có biết ngay nên làm gì tiếp theo không?

Step 7 — Giảm density

Bỏ hoặc đẩy detail không cần thiết sang tầng sau.

Step 8 — Thêm Memphis decoration cuối cùng

Chỉ thêm nếu bố cục thật sự cần.

Step 9 — Kiểm tra interaction states

Selected / pressed / loading / error.

Step 10 — Kiểm tra consistency

So với các màn hình hiện có.

31. Quality Checklist

Trước khi chốt một màn hình:

Có 1 mục tiêu chính rõ ràng?

Có 1 focal point rõ?

Primary CTA nổi bật nhất?

Typography hierarchy rõ?

Phần lớn text được căn trái?

Có đủ whitespace?

Màu dominant rõ?

Không dùng gradient?

Không dùng blurred shadow?

Border/radius nhất quán?

Shadow chỉ xuất hiện ở component cần nhấn?

Selected state có hơn 1 tín hiệu?

Memphis decoration có mục đích?

UI có đang quá nhiều màu?

Body text có dễ đọc?

Icon có đồng nhất?

UI có cảm giác EdTech chứ không phải game?

UI có cảm giác creator-led chứ không corporate?

Có ít nhất 1 signature NeoBrutal element ở màn hình quan trọng?

Visual có hỗ trợ nhiệm vụ thay vì cạnh tranh với nhiệm vụ?

32. Quick Design Prompt

Dùng khi giao cho AI/UI agent:

Modern playful Neo‑Brutalist EdTech mobile interface with Swiss editorial grid, bold sans-serif typography, thick black outlines, hard bottom-right offset shadows, cream and saturated pastel palette, square and rectangular modular cards with only slight corner rounding, pronounced hard bottom-right box shadows, semantic rectangular keyword highlights, restrained Memphis geometric accents, strong alignment, generous negative space, flat colors, high contrast, friendly educational tone, creator-led personality, and clear mobile interaction hierarchy. Avoid gradients, glassmorphism, blurred shadows, generic SaaS dashboard aesthetics, excessive decoration, and visual clutter.

33. Final Design Rule

Phong cách không được hiểu là:

“viền đen + màu sặc sỡ + shadow lớn”.

Định nghĩa đúng là:

Một hệ thống EdTech có cấu trúc Swiss rõ ràng, sử dụng các khối vuông/chữ nhật bo nhẹ và hard box-shadow nổi rõ làm ngôn ngữ Neo‑Brutal chủ đạo, thêm Memphis vừa đủ để có personality, và dùng Modern EdTech patterns để tạo trải nghiệm học tập dễ hiểu, vui và có động lực.

Tỷ lệ cuối cùng

Neo‑Brutalism              55% → Personality
Swiss / International      25% → Structure
Memphis                    10% → Playfulness
Modern EdTech              10% → Learning Experience

Design mantra

Chỉ những thứ quan trọng mới được phép “ồn”.