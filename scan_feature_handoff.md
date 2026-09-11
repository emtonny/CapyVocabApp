# AI Scan Feature Handoff

> Tài liệu bàn giao kỹ thuật cho agent tiếp quản chức năng chính: chụp/chọn
> ảnh, nhận diện từ vựng bằng Gemini Vision và vẽ note từ vựng lên ảnh.

## 0. Thông tin baseline

- Ngày đối chiếu mã nguồn: `2026-08-25`.
- Branch tại thời điểm lập handoff: `AI-scan`.
- Commit nền: `ac576d70c89473fefe1bcf5a4d15e5bc16b352e4`.
- Flutter: `3.44.4` stable.
- Dart: `3.12.2`.
- Supabase CLI: `2.114.0`.
- Tài liệu này mô tả **hiện trạng trong source**, không mô tả đầy đủ sản phẩm
  mong muốn trong tương lai.
- Khi tài liệu và code khác nhau, code và test hiện tại là nguồn sự thật.
- Không dùng mô tả Gemini 1.5 trong `README.md`/comment `pubspec.yaml` làm căn
  cứ runtime; Edge Function hiện cấu hình model khác, xem mục 6.

Verification tại baseline:

```powershell
flutter test test/features/ai_scan test/features/vocab_scan `
  test/core/services/gemini_vision_service_test.dart
```

- Kết quả: `142` tests passed.
- `flutter analyze`: pass, không có issue.
- Deno không có trong PATH trên máy lập handoff, nên Edge TypeScript tests chưa
  được chạy tại baseline này; xem lệnh ở mục 17.4.
- Browser-only compressor test cần Chrome runner riêng; lần kiểm tra trực tiếp
  tại baseline bị treo khi khởi động runner và đã được dừng, nên không tính là
  pass.

## 1. Phạm vi và trạng thái hiện tại

### 1.1 Phần đã chạy trong flow chính

1. Mở bottom sheet Scan từ nút camera ở bottom navigation.
2. Chụp ảnh bằng camera hoặc chọn ảnh trong thư viện.
3. Có camera implementation riêng trên web.
4. Đọc bytes, tạo preview và tính aspect ratio.
5. Nén ảnh thành JPEG không quá 300 KiB, bỏ EXIF.
6. Lưu JPEG cục bộ/tạm thời tùy nền tảng.
7. Gửi Base64 JPEG cùng Supabase access token tới Edge Function.
8. Edge Function gọi chuỗi model Gemini, chuẩn hóa kết quả.
9. Flutter parse, validate, deduplicate, rank và normalize bounding box.
10. Lưu record kết quả vào SQLite trên native hoặc RAM trên web.
11. Vẽ bounding box, connector và card từ vựng trực tiếp trong bottom sheet.
12. Cho phép mở fullscreen và zoom/pan toàn bộ ảnh + overlay.

### 1.2 Phần có source nhưng chưa nối vào flow chính

- `ScanFlowController.scanAndNavigate()` và route `/scan-overlay` tồn tại,
  nhưng `PhotoScanBottomSheet` hiện gọi `scan()` và render kết quả inline.
- Chọn mẫu note chỉ thay đổi `_selectedTemplateIndex`; không thay đổi painter,
  data hoặc output. `subtitle` được truyền vào builder nhưng không được render.
- `NoteTemplateSelector` riêng vẫn là widget rỗng/TODO.
- `VocabCanvasOverlay` nhận `ttsService` và `onLabelTap`, nhưng caller hiện tại
  không truyền callback; chạm label và phát âm chưa hoạt động trong flow chính.
- `sceneWords` được giữ để tương thích nhưng placement hiện chỉ dùng `words`.
- `PhotoScanBottomSheet.show()` và `ScanNotifier.clear()` hiện không có caller
  trong `lib/`.
- Màn hình Thư viện chỉ là “Đang phát triển”; local datasource mới có `save`,
  chưa có list/get/delete/update.
- `SelectedVocabScreen`, `VocabEntity`, `PhotoNoteEntity` vẫn là scaffold/TODO.
- Không upload ảnh scan lên Supabase Storage và không đồng bộ album theo user.

## 2. Sơ đồ kiến trúc

```text
BottomNavBar
  -> GoRouter /scan
     -> PhotoScanBottomSheet
        -> ScanImagePicker / web CameraCaptureView
        -> ScanImageCompressor
        -> ScanImageStorage.saveJpeg
        -> ScanFlowController.scan
           -> ScanNotifier.scanImage
              -> ScanImageStorage.readBytes
              -> GeminiVisionService
                 -> Supabase Edge Function: gemini-vision-scan
                    -> Gemini model health store (best effort)
                    -> Gemini model chain
                    -> response cleanup / bounding-box shrink
              -> ScanResultStore.save
                 -> SQLite on native
                 -> memory store on web
        -> VocabCanvasOverlay
           -> image/bbox transform
           -> label size measurement
           -> forbidden zones
           -> deterministic placement solver
           -> connector geometry/painter
           -> cards: number + word + IPA + Vietnamese meaning
```

Hai feature directory cùng tham gia một chức năng:

- `lib/features/ai_scan`: input ảnh, orchestration, network, persistence, màn
  hình và widget overlay.
- `lib/features/vocab_scan`: hình học thuần cho placement/card/connector. Đây
  không phải flow scan thứ hai.

## 3. Điều kiện trước khi vào Scan

### 3.1 Khởi động app

`lib/main.dart` thực hiện:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Load `.env`.
3. Khởi tạo Supabase bằng `SUPABASE_URL` và `SUPABASE_ANON_KEY`.
4. Query thử bảng `vocabularies`.
5. Chỉ render `CapyVocabApp` khi health check thành công; nếu không, app hiện
   màn hình mất kết nối và nút thử lại.
6. Root app được bọc trong `ProviderScope`.

Hệ quả: scan không thể mở nếu startup health check Supabase thất bại, kể cả
phần chọn/nén ảnh về lý thuyết có thể chạy local.

### 3.2 Auth và onboarding

`lib/core/routes/app_router.dart` redirect:

- Không có Supabase session -> `/auth`.
- Có session nhưng chưa hoàn thành onboarding -> `/onboarding`.
- Hoàn thành onboarding -> được vào `/home` và các route chính.

Mỗi lần redirect có thể query `users.onboarding_completed`. Client scan cũng
tự kiểm tra access token trước khi gửi request.

### 3.3 Entry point

- File: `lib/shared/navigation/bottom_nav_bar.dart`.
- Nút: key `bottom-nav-camera-button`.
- Hành động: `context.push('/scan')`.
- Route `/scan` là `CustomTransitionPage<void>`:
  - `opaque: false`;
  - backdrop `0x66000000`;
  - `barrierDismissible: true`;
  - child `PhotoScanBottomSheet`.

Bottom sheet cũng tự đóng khi người dùng chạm vùng ngoài hoặc vuốt xuống với
`primaryVelocity > 200`.

## 4. Runtime sequence phía Flutter

### 4.1 Chọn nguồn ảnh

UI có hai nút:

| Nút | Key | Luồng |
| --- | --- | --- |
| Chụp ảnh thô | `pick-camera-button` | `_captureAndScan()` |
| Tải ảnh lên | `pick-gallery-button` | `_pickAndScan(gallery)` |

`_pickAndScan()` là orchestration method chính trong
`lib/features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart`.

Đầu mỗi lượt chọn:

1. Nếu `_isProcessing == true`, return.
2. Xóa `_previewBytes`, `_imageAspectRatio`, `_scanRecord`.
3. Đặt status về `Đang chuẩn bị ảnh...`.
4. Gọi picker hoặc web capture override.

Lưu ý: `_isProcessing` chỉ được đặt `true` **sau khi picker trả ảnh**. Trong
thời gian native picker đang mở, guard nội bộ chưa khóa lượt gọi thứ hai.
Vì preview/result cũ bị xóa trước khi mở picker, nếu người dùng bắt đầu lượt
chọn mới rồi cancel, preview/result của lượt trước vẫn đã bị xóa.

### 4.2 Camera và gallery trên native

`DeviceScanImagePicker` bọc package `image_picker`:

```dart
pickImage(
  source: camera ? ImageSource.camera : ImageSource.gallery,
  requestFullMetadata: false,
)
```

Kết quả được chuyển thành:

```dart
class PickedScanImage {
  Uint8List bytes;
  String name;
}
```

- `name` hiện không được dùng sau khi chọn.
- Người dùng hủy picker -> trả `null`, không hiện lỗi và không chạy pipeline.
- Native/plugin exception -> `ScanImagePickerException` với message theo nguồn.

### 4.3 Camera riêng trên web

Web không dùng nhánh camera của `image_picker`. `_captureWithWebCamera()` push
`CameraCaptureView` fullscreen và đợi `XFile` trả về.

`BrowserCameraCaptureSession`:

1. Gọi `navigator.mediaDevices.getUserMedia({video: ..., audio: false})`.
2. Liệt kê `videoinput` bằng `enumerateDevices()`.
3. Xác định camera đang active.
4. Nếu camera mặc định có nhãn IR/infrared/Windows Hello, thử chuyển sang camera
   thường đầu tiên.
5. Dùng `HTMLVideoElement` autoplay, muted, playsInline để preview.
6. Đặt `pointerEvents: none` cho element video để control Flutter nhận tap.
7. Nếu có nhiều camera, UI cho đổi device.
8. Khi chụp, vẽ frame video lên `HTMLCanvasElement`.
9. Encode JPEG bằng `canvas.toBlob(..., 'image/jpeg', 0.92)`.
10. Trả `XFile.fromData` về bottom sheet.
11. Khi đóng/dispose, pause video, bỏ `srcObject`, stop toàn bộ media tracks.

Web camera cần secure context: HTTPS khi deploy; localhost được browser cho
phép trong development.

Các nhóm lỗi camera web:

- Permission/access/not-allowed -> yêu cầu cấp quyền, có nút thử lại.
- Không tìm thấy camera -> gợi ý đóng để dùng thư viện, không hiện thử lại.
- Lỗi khác -> hiển thị code + description của browser và cho thử lại.

### 4.4 Preview và aspect ratio

Sau khi có `PickedScanImage`:

1. `_updateImageDimensions()` dùng `ui.instantiateImageCodec`.
2. Aspect ratio là `image.width / image.height`.
3. Bytes gốc được gán vào `_previewBytes` để preview xuất hiện ngay.
4. `_isProcessing = true`.
5. Status chuyển sang `Đang nén ảnh...`.

Lỗi khi chỉ đọc dimensions bị bỏ qua; UI fallback aspect ratio `4 / 3`.

### 4.5 Nén ảnh

`FlutterScanImageCompressor` có contract:

- Input phải khác rỗng và decode được.
- Output là JPEG.
- `keepExif: false`.
- Dung lượng tối đa `300 * 1024` bytes.
- Giữ tỷ lệ ảnh.

Các cạnh tối đa được thử theo thứ tự:

```text
1024 -> 896 -> 768 -> 640 -> 512 -> 384
```

Mỗi kích thước thử các quality:

```text
85 -> 70 -> 55 -> 40 -> 25 -> 15
```

Compressor trả ngay lần đầu đạt <= 300 KiB. Nếu mọi tổ hợp vẫn quá lớn, nó
ném `ScanImagePreparationException` thay vì gửi phiên bản vượt limit.

Sau khi nén:

- Preview đổi sang bytes JPEG đã nén.
- Aspect ratio được đọc lại.
- Status đổi thành `Đang nhận diện từ vựng...`.

Không có status riêng cho bước lưu local; lúc đang lưu, UI đã hiện status nhận
diện.

### 4.6 Lưu JPEG trước scan

Factory dùng conditional import:

```text
dart.library.io          -> IoScanImageStorage
dart.library.js_interop  -> MemoryScanImageStorage
fallback                 -> MemoryScanImageStorage
```

Native IO:

```text
<ApplicationDocumentsDirectory>/capy_scans/
  capy_scan_<microsecondsSinceEpoch>.jpg
```

- Ghi bytes với `flush: true`.
- `localPath` là absolute file path.

Web/memory:

```text
memory://capy_scan_<microsecondsSinceEpoch>.jpg
```

- Bytes được copy vào `Map<String, Uint8List>`.
- Reload app/tab làm mất dữ liệu.

Ảnh được lưu **trước** khi gọi Vision. Không có cleanup khi Vision hoặc SQLite
thất bại, nên scan lỗi có thể để lại file JPEG mồ côi trên native.

### 4.7 Orchestration và Riverpod state

`ScanFlowController.scan(context, ref, localPath)` gọi
`scanProvider.notifier.scanImage(localPath)`.

Providers:

| Provider | Implementation mặc định |
| --- | --- |
| `scanImagePickerProvider` | `DeviceScanImagePicker` |
| `scanImageCompressorProvider` | `FlutterScanImageCompressor` |
| `scanImageStorageProvider` | platform storage factory |
| `visionScanClientProvider` | `GeminiVisionService` |
| `scanResultStoreProvider` | SQLite native / memory web |
| `scanProvider` | `ScanNotifier` |

`ScanNotifier` giữ `AsyncValue<ScanResultRecord?>`:

```text
initial: AsyncData(null)
  -> scanImage(): AsyncLoading
     -> success: AsyncData(record)
     -> failure: AsyncError(error, stackTrace), rồi rethrow
```

Thứ tự bắt buộc trong `scanImage()`:

1. Nếu state đang loading, ném `StateError`.
2. Đọc lại bytes bằng `_imageStorage.readBytes(localPath)`.
3. Gọi `_visionClient.analyzeImageBytes(imageBytes)`.
4. Chỉ khi Vision thành công mới gọi `_resultStore.save(...)`.
5. Trả record cho bottom sheet.

`ScanFlowController` bắt exception để log và hiện dialog. Nó trả `null` sau
lỗi; caller không được coi `null` là kết quả scan rỗng.

### 4.8 Kết thúc flow trong bottom sheet

Flow chính hiện gọi:

```dart
final record = await ScanFlowController.scan(...);
if (record != null) {
  setState(() => _scanRecord = record);
}
```

Nó **không gọi** `scanAndNavigate()`. Sau thành công:

- `_scanRecord` cung cấp vocabulary cho preview hiện tại.
- `_isProcessing` về `false` trong `finally`.
- Hai nút camera/gallery được bật lại.
- Bottom sheet mở rộng tối đa từ khoảng 55% lên 82% chiều cao màn hình khi có
  preview/đang xử lý.

## 5. Client-to-Edge API contract

### 5.1 Endpoint

`GeminiVisionService` dựng URL từ Supabase REST URL runtime:

```text
<supabase-origin>/functions/v1/gemini-vision-scan
```

Không hardcode project host trong production path; constructor cho phép override
endpoint/client/token provider để test.

### 5.2 Request

Flutter Base64-encode JPEG và gửi:

```http
POST /functions/v1/gemini-vision-scan
Authorization: Bearer <current Supabase access token>
Content-Type: application/json; charset=utf-8
```

```json
{
  "image_base64": "<base64 JPEG>"
}
```

- Không có access token -> client dừng trước HTTP và ném
  `GeminiAuthenticationException`.
- Timeout tổng phía Flutter: 90 giây.
- `http.ClientException` được chuyển thành `GeminiApiException(statusCode: 0)`.

### 5.3 Edge input validation

Edge Function:

- Sinh một `scanId` UUID cho logging/correlation.
- Hỗ trợ CORS `OPTIONS`.
- Thiếu `GEMINI_API_KEY` -> HTTP 500 `server_misconfigured`.
- Thiếu/sai kiểu `image_base64` -> HTTP 400 `invalid_request`.
- Base64 dài hơn 600,000 ký tự -> HTTP 413 `image_too_large`.

Các validation chưa có trong handler:

- Không reject method khác `POST` (ngoài nhánh đặc biệt `OPTIONS`).
- Không decode để xác nhận chuỗi là Base64 hợp lệ.
- Không sniff/validate MIME hoặc magic bytes; request tới Gemini luôn khai báo
  `image/jpeg`.

Frontend cố giữ JPEG <= 300 KiB, nên Base64 thông thường khoảng <= 409,600 ký
tự, nằm dưới limit Edge. Cả hai giới hạn vẫn phải được giữ đồng bộ khi sửa.

Edge handler không tự parse/verify JWT trong source. Flutter gửi bearer token;
việc enforce JWT ở gateway/deployment không được cấu hình riêng cho function
này trong `supabase/config.toml`, vì vậy agent triển khai phải xác nhận cấu hình
project thay vì mặc định rằng handler đã tự authorization.

## 6. Gemini request và model failover

### 6.1 Output yêu cầu từ Gemini

Edge prompt yêu cầu tối đa 12 vật thể:

- rõ, phổ biến và hữu ích cho học từ vựng;
- ưu tiên vật lớn, rõ và dễ nhận diện;
- mỗi loại chỉ lấy một đại diện rõ nhất;
- tên tiếng Anh tự nhiên, lowercase, thường là singular;
- không suy diễn subtype/brand/function/đặc điểm không nhìn thấy;
- IPA;
- nghĩa tiếng Việt sát vật thể;
- bounding box nguyên trong hệ tọa độ 0..1000;
- JSON thuần, không explanation.

Response schema phía Edge:

```json
{
  "words": [
    {
      "number": 1,
      "word": "chair",
      "phonetic": "/tʃeə(r)/",
      "meaning_vi": "cái ghế",
      "box": { "x": 100, "y": 200, "w": 250, "h": 400 }
    }
  ]
}
```

`x`, `y` là góc trên trái; `w`, `h` là extent. Schema bắt buộc đủ năm field
trên mỗi word.

### 6.2 Model chain hiện tại

`supabase/functions/gemini-vision-scan/gemini_client.ts`:

```text
1. gemini-3.5-flash-lite
2. gemini-3.6-flash
```

Config chung:

- `responseMimeType: application/json`.
- `responseSchema`: schema ở trên.
- `maxOutputTokens: 8192`.
- Model không phải `gemini-2.5-*` dùng `thinkingLevel: low`.
- Timeout mỗi attempt: 35 giây.

Failover:

- Status có thể chuyển model: `404, 429, 500, 502, 503, 504`.
- Riêng 503: retry một lần trên cùng model sau 750 ms, rồi mới chuyển model.
- Network error hoặc timeout của attempt: chuyển model ngay.
- `400, 401, 403, 413`: không chuyển model.
- Với timeout/network, mỗi model chỉ có một attempt nên hai lần 35 giây nằm
  dưới client timeout 90 giây. Tuy nhiên 503 được phép hai attempt trên mỗi
  model; nếu từng response 503 đều chậm, worst case có thể vượt 90 giây. Test
  hiện chỉ bảo vệ hằng số 90 giây, không chứng minh mọi nhánh failover hoàn tất
  trước client timeout.

### 6.3 Model health store

Nếu Edge có đủ `SUPABASE_URL` và `SUPABASE_SERVICE_ROLE_KEY`, nó dùng
`gemini_model_health` theo kiểu best effort:

- Read/write timeout 1.5 giây.
- Model marked unhealthy được đưa xuống cuối chain ở scan sau.
- Success reset failures về 0 và healthy=true.
- System failure tăng `consecutive_failures`.
- Sau 3 system failures liên tiếp, `is_healthy=false`.
- Client error/quota không được tính là health failure.
- Lỗi đọc/ghi health store chỉ log warning; scan vẫn tiếp tục với chain mặc
  định.

Schema/RPC nằm trong migration:

`supabase/migrations/20260815141623_add_gemini_model_health.sql`.

Service role là writer; không được đưa service-role key xuống Flutter client.

## 7. Hậu xử lý ở Edge

Khi Gemini trả HTTP success:

1. Đọc `candidates[0].content.parts[0].text`.
2. Không có text -> HTTP 422 `empty_response`.
3. JSON parse lỗi/truncated -> HTTP 422 `truncated_response`.
4. Nếu `parsed.words` là array:
   - rank theo diện tích box gốc giảm dần;
   - deduplicate theo `word.trim().toLowerCase()`;
   - lấy tối đa `MAX_WORDS = 12`;
   - shrink mỗi box quanh tâm với ratio `0.5` cho cả width và height;
   - clamp về 0..1000 và giữ kích thước tối thiểu 1;
   - đánh lại `number = index + 1`.
5. Log các box quá lớn/quá nhỏ và metadata scan thành công.
6. Trả JSON đã xử lý về Flutter.

Quan trọng: shrink ratio `0.5` theo hai chiều làm diện tích còn khoảng `25%`
box Gemini ban đầu. Việc rank diễn ra **trước** shrink.

Hiện Edge schema chỉ có `words`; không yêu cầu `scene_words`.

## 8. Parse và domain model phía Flutter

### 8.1 `GeminiVisionResult`

Fields:

```text
detectedVocabulary : List<VocabDetection>
sceneDetections    : List<VocabDetection>
imageLanguage      : String (default 'en')
confidence         : double (default 0.0)
```

Behavior `fromJson`:

1. `words` bắt buộc là list, nếu không ném `FormatException`.
2. Parse từng item thành `VocabDetection`.
3. Nếu có `scene_words`, parse riêng; nếu không thì dùng `words` làm scene.
4. Với `words`, giữ box lớn nhất cho mỗi normalized word.
5. Sort diện tích box giảm dần, tie-break bằng word.
6. Lấy tối đa `maxGeminiVocabularyWords = 15`.
7. Đánh số lại liên tục.

Edge hiện chỉ trả tối đa 12, nhưng client và placement solver chịu tối đa 15.
Đây là hai giới hạn khác nhau; không thay một bên mà quên test bên còn lại.

`imageLanguage` và `confidence` hiện không được đọc từ JSON trong factory nên
luôn giữ default. `toJson()` chỉ serialize `words` và `scene_words`.

### 8.2 `VocabDetection`

Fields runtime:

```text
number       : int
word         : String
phonetic     : String
meaning      : String       // đọc từ meaning_vi
partOfSpeech : String       // default '', chưa parse/serialize
x, y, w, h   : double       // normalized 0.0..1.0 trong Flutter
```

Validation:

- `word`, `phonetic`, `meaning_vi` phải là string.
- `number` phải là int dương; response cũ thiếu number dùng fallback theo index.
- `box.x/y/w/h` phải là int 0..1000.
- `x + w <= 1000` và `y + h <= 1000`.
- Sau validate, chia mỗi coordinate cho 1000.

Edge response schema đặt minimum `1` cho `w/h`, nhưng Flutter parser hiện chấp
nhận cả `0` vì dùng chung validator 0..1000 cho bốn coordinate. Đây là tolerance
khác contract server; không được mô tả hai validator là hoàn toàn giống nhau.

`toJson()` nhân ngược coordinate với 1000 và round.

## 9. Mapping lỗi Edge/HTTP sang UI

| Tình huống/status | Flutter exception | Message UI hiện tại |
| --- | --- | --- |
| Không có token | `GeminiAuthenticationException` | Phiên đăng nhập đã hết hạn... |
| 401/403 | `GeminiAuthenticationException` | Phiên đăng nhập đã hết hạn... |
| 413 | `GeminiImageTooLargeException` | Ảnh quá lớn, vui lòng chọn ảnh khác |
| 422 | `GeminiRecognitionException` | Không nhận diện được, thử ảnh khác |
| 429 | `GeminiQuotaException` | Hệ thống đang bận, thử lại sau |
| 503 | `GeminiUnavailableException` | Dịch vụ Gemini tạm thời không khả dụng... |
| 504 hoặc client timeout | `GeminiTimeoutException` | Quá thời gian chờ, thử lại |
| 500/502/status khác | `GeminiApiException` | Đã có lỗi, thử lại |
| HTTP 200 sai schema | `GeminiInvalidResponseException` | Không nhận diện được, thử ảnh khác |
| Network `ClientException` | `GeminiApiException(0)` | Đã có lỗi, thử lại |

Với 503, exception còn giữ `errorCode`, `upstreamStatus`, `scanId` để debug,
nhưng dialog chỉ hiện `message`.

UI chia lỗi thành hai dialog:

1. **Không thể chuẩn bị ảnh**: picker, compress, local storage preparation.
2. **Không thể quét ảnh**: Gemini/Vision, read persisted image và lỗi scan khác.

Mọi lỗi đều log `debugPrint` + stack trace. Không có telemetry/crash reporting
riêng cho scan.

## 10. Persistence contract

### 10.1 Record

```dart
class ScanResultRecord {
  int id;
  String localPath;
  String vocabJson;
  GeminiVisionResult result;
  DateTime createdAt;
}
```

`vocabJson` là `jsonEncode(result.toJson())`.

### 10.2 Native SQLite

- Database: `<getDatabasesPath()>/capy_vocab.db`.
- Version: 1.
- Table được tạo bằng `CREATE TABLE IF NOT EXISTS` ở cả `onCreate` và `onOpen`.

```sql
CREATE TABLE scan_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  local_path TEXT NOT NULL,
  vocab_json TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);
```

Insert thực tế truyền `created_at` từ `DateTime.now().toUtc().toIso8601String()`
và dùng `ConflictAlgorithm.abort`.

Không có:

- `user_id`;
- foreign key;
- cloud sync;
- list/read/update/delete method;
- migration strategy ngoài database version 1;
- transaction bao phủ cả file JPEG và DB row;
- cleanup orphan file;
- encryption at rest do app tự quản lý.

### 10.3 Web

- Ảnh: `MemoryScanImageStorage`.
- Record: `MemoryScanResultStore`.
- ID tăng từ 1 trong lifetime của provider instance.
- `MemoryScanResultStore` không giữ một collection nội bộ; nó chỉ tạo và trả
  `ScanResultRecord`. Record hiện còn được giữ bởi Riverpod state/bottom sheet
  trong lifetime hiện tại, không thể query lại thành history.
- Không có persistence sau reload và không có album history.

## 11. Render overlay

### 11.1 Input

Bottom sheet truyền:

```dart
VocabCanvasOverlay(
  imageProvider: MemoryImage(compressedBytes),
  words: record.result.detectedVocabulary,
  sceneWords: record.result.placementContext,
)
```

Hiện `sceneWords` không tham gia placement. Khi `words` rỗng, bottom sheet chỉ
render `Image.memory` thay vì `VocabCanvasOverlay`.

### 11.2 Image coordinate transform

`ImageRectCalculator` dùng contain fit:

- scale = min(canvasWidth/sourceWidth, canvasHeight/sourceHeight);
- ảnh được căn giữa;
- normalized detection `(x,y,w,h)` được map vào rect ảnh thực trên canvas.

Placement không phụ thuộc kích thước preview hiện tại. Nó dùng reference canvas
cố định width 400 và height theo aspect ratio ảnh, sau đó scale đồng nhất toàn
bộ geometry/text/stroke sang viewport.

### 11.3 Placement cache

`_PlacementCache` key gồm:

- snapshot mọi field của `words`;
- source image size;
- full style config;
- compact style config.

Resize canvas/zoom/rebuild không làm solve lại nếu key không đổi. Thay word hoặc
kích thước ảnh thật mới recompute. Nếu words > 15 hoặc solver ném exception,
widget fallback sang chỉ vẽ bounding box, không crash UI.

### 11.4 Placement pipeline

1. Đo card gồm word, IPA, nghĩa Việt, badge và decoration.
2. Chuyển mỗi detection thành anchor box pixel-space.
3. Tạo forbidden zone bằng object box inflate 6 px, clamp trong canvas.
4. Sinh candidate quanh object theo 5 vòng bán kính và 8 góc cơ bản.
5. Có angular recovery ±15° và ±30°.
6. Dùng MRV: ưu tiên word có ít candidate hợp lệ nhất; tie-break bằng label
   area lớn hơn rồi source index.
7. Candidate lý tưởng phải ở trong canvas, tránh forbidden zones, label đã đặt
   và connector collision.
8. Fallback tuần tự:
   - font/card compact;
   - cho phép label overlap tối đa 20% trong điều kiện kiểm soát;
   - ưu tiên vị trí edge connector-safe;
   - relax connector constraint;
   - edge last resort, có metadata báo overlap.
9. Chọn connector route tránh label/object/connector khác khi có thể.

`PlacementQuality`:

```text
ideal
fallbackSmallerFont
fallbackAllowOverlap
fallbackEdge
```

### 11.5 Painter output

Painter vẽ theo thứ tự:

1. Bounding box amber fill alpha 0.22.
2. Border deep orange 2 px.
3. Connector/arrow.
4. Label card màu warm white, viền Capy brown.
5. Number badge hai chữ số (`01`, `02`, ...).
6. Deer sticker/cookie decoration nếu geometry đủ chỗ.
7. Ba dòng text:
   - English word;
   - IPA;
   - Vietnamese meaning.

Label hit testing có hỗ trợ card, badge và decoration; label vẽ sau nhận tap
trước nếu fallback buộc overlap. Tuy nhiên current callers không truyền
`onLabelTap`, nên overlay được bọc `IgnorePointer` và không có hành động khi
chạm.

### 11.6 Fullscreen zoom

Nút key `zoom-image-button` mở `Dialog.fullscreen`:

- background đen;
- `InteractiveViewer` minScale 0.5, maxScale 4.0;
- ảnh và overlay nằm chung một child nên biến đổi cùng nhau;
- nút đóng ở góc trên phải.

## 12. Route `/scan-overlay` và flow không còn là mặc định

`ScanFlowController.scanAndNavigate()`:

1. Gọi `scan()`.
2. Nếu có record và context còn mounted, push `/scan-overlay` kèm `extra`.

`AppRouter` yêu cầu `extra is ScanResultRecord`; nếu thiếu/sai kiểu, hiện màn
“Không tìm thấy kết quả quét”. `ScanResultOverlayScreen` đọc JPEG từ
`localPath` rồi render `VocabCanvasOverlay`.

Production bottom sheet hiện không gọi method này. Test
`scan_flow_controller_test.dart` vẫn bảo vệ flow điều hướng độc lập. Tên test
“scan rồi mở overlay” trong `photo_scan_bottom_sheet_test.dart` đã cũ: assertion
thực tế chỉ kiểm tra inline preview/zoom, không kiểm tra route navigation.

Agent sau cần quyết định rõ một trong hai UX trước khi refactor:

- Giữ kết quả inline và xóa/deprecate flow route riêng; hoặc
- Chuyển flow chính về `scanAndNavigate()` và cập nhật test/UI tương ứng.

Đây là thay đổi user-visible, không được tự suy đoán.

## 13. Lifecycle, concurrency và failure semantics

### 13.1 Invariants hiện có

- `ScanNotifier` không cho hai Vision scan đồng thời trong cùng provider.
- Sau khi picker trả ảnh, `_isProcessing` vô hiệu hóa hai action buttons.
- Có `mounted` checks sau phần lớn async boundary.
- `_isProcessing` được reset trong `finally` nếu widget còn mounted.
- Vision lỗi thì không lưu `ScanResultRecord`.
- Local save lỗi thì không gọi Vision.
- Compress lỗi thì không gọi storage/Vision.

### 13.2 Khoảng trống/rủi ro đã xác nhận

- Không có `PopScope` hoặc cancellation token cho lượt scan. Nếu route bị đóng
  bằng Back/navigation trong lúc xử lý, Future không bị cancel; scan và
  persistence có thể vẫn hoàn tất sau khi UI đóng. Loading overlay có thể chặn
  tap/drag trực tiếp, nhưng không phải cơ chế cancellation.
- Native picker chưa bị khóa trong chính thời gian chờ picker trả về.
- Bắt đầu lượt pick mới xóa kết quả cũ ngay; cancel picker không khôi phục lại
  preview/record trước đó.
- JPEG đã lưu không được xóa nếu Vision/DB insert lỗi.
- Không có retry button trực tiếp trong dialog scan; user đóng dialog rồi bấm
  chọn/chụp lại.
- Không có idempotency key; retry tạo file và DB row mới.
- Không có delete/retention policy cho JPEG/SQLite.
- Không có progress phần trăm; chỉ có status text theo phase.
- Ảnh nén được gửi qua Supabase Edge tới Google Gemini; cần phản ánh trong privacy
  policy/consent nếu sản phẩm phát hành.
- JPEG và vocab JSON nằm local, không có application-layer encryption.
- Nếu Gemini trả JSON hợp lệ với `words: []`, flow vẫn lưu record và UI chỉ hiện
  ảnh; Edge chỉ trả 422 khi thiếu raw text hoặc parse lỗi.
- `partOfSpeech`, `imageLanguage`, `confidence` hiện là field danh nghĩa, chưa có
  end-to-end data.

## 14. Platform matrix

| Concern | Non-web theo nhánh source | Web |
| --- | --- | --- |
| Camera | `image_picker` native | Custom `getUserMedia` screen |
| Gallery | `image_picker` | `image_picker` web branch |
| Compress | `flutter_image_compress` | `flutter_image_compress` web support |
| Image storage | App documents/capy_scans | In-memory Map |
| Result storage | SQLite `sqflite` | In-memory store |
| Persistence after restart | Có file + row, nhưng chưa có UI đọc | Không |
| Camera selection | Theo native picker | Dropdown khi >1 device |
| Secure-context requirement | N/A | HTTPS/localhost |

Repository hiện không chứa đầy đủ runner config tiêu chuẩn:

- Không thấy `android/app/src/main/AndroidManifest.xml`.
- Không thấy `ios/Runner/Info.plist`.
- Vì vậy không thấy khai báo camera/photo usage description hoặc permission
  tương ứng trong source hiện tại.

Widget/unit tests không chứng minh native app đã có permission configuration.
Trước khi build/release Android/iOS, agent phải kiểm tra/khôi phục runner files
và permission theo version plugin đang khóa trong `pubspec.lock`.

Provider chỉ phân nhánh bằng `kIsWeb`: mọi target không phải web đều chọn
`ScanResultLocalDataSource`/`sqflite`. Điều này không tự chứng minh Windows,
Linux hoặc mọi desktop runner được plugin hiện tại hỗ trợ; phải build/test target
cụ thể trước khi tuyên bố hỗ trợ desktop.

## 15. Cấu hình và secret

Flutter `.env` dùng:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

`.env.example` còn liệt kê `GEMINI_API_KEY`, nhưng runtime Flutter scan không
đọc key này. Gemini key phải là Edge Function secret, không đưa vào client app
hoặc bundle Flutter.

`pubspec.yaml` hiện khai báo nguyên `.env` trong `flutter.assets`. Vì vậy nếu
đặt `GEMINI_API_KEY` thật vào `.env`, key có nguy cơ bị đóng gói cùng client dù
code Flutter không đọc nó. Chỉ để cấu hình public/publishable dành cho client
trong asset này; chuyển mọi server secret sang Supabase Edge secrets.

Edge runtime dùng:

```text
GEMINI_API_KEY             required
SUPABASE_URL               required để bật health store
SUPABASE_SERVICE_ROLE_KEY  required để bật health store
```

Không log Base64 ảnh hoặc secret. Edge chỉ log error body rút gọn, scanId,
model, attempts, finish reason, usage metadata và word count.

## 16. Source map để tiếp quản

### 16.1 Entry, routing, UI orchestration

| File | Trách nhiệm |
| --- | --- |
| `lib/shared/navigation/bottom_nav_bar.dart` | Nút camera mở `/scan` |
| `lib/core/routes/app_router.dart` | Auth redirect, `/scan`, `/scan-overlay` |
| `lib/features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart` | Flow chính và inline result UI |
| `lib/features/ai_scan/presentation/controllers/scan_flow_controller.dart` | Scan error dialog và optional navigation |
| `lib/features/ai_scan/presentation/providers/scan_provider.dart` | DI providers + `ScanNotifier` |
| `lib/features/ai_scan/presentation/widgets/scan_loading_overlay.dart` | Blocking loading overlay có semantics live region |
| `lib/features/ai_scan/presentation/screens/scan_result_overlay_screen.dart` | Route result riêng, hiện không dùng trong flow chính |

### 16.2 Image input/preparation/storage

| File | Trách nhiệm |
| --- | --- |
| `data/services/scan_image_picker.dart` | Camera/gallery abstraction |
| `data/services/scan_image_compressor.dart` | JPEG <= 300 KiB |
| `data/services/scan_image_storage.dart` | Storage interface + exception |
| `data/services/scan_image_storage_factory.dart` | Conditional import |
| `data/services/scan_image_storage_io.dart` | Persistent local JPEG |
| `data/services/scan_image_storage_memory.dart` | In-memory JPEG |
| `data/services/scan_image_storage_web.dart` | Web factory |
| `presentation/widgets/camera_capture_view.dart` | Web camera screen + error UX |
| `presentation/widgets/camera_capture_session.dart` | Web camera interfaces |
| `presentation/widgets/camera_capture_session_web.dart` | Browser implementation |
| `presentation/widgets/camera_capture_session_stub.dart` | Non-web guard |

Các path `data/...` trong bảng trên nằm dưới `lib/features/ai_scan/`.

### 16.3 Vision và persistence

| File | Trách nhiệm |
| --- | --- |
| `lib/core/services/gemini_vision_service.dart` | HTTP client, result model, validation, error mapping |
| `lib/features/ai_scan/data/datasources/scan_result_local_datasource.dart` | SQLite/memory result store |
| `supabase/functions/gemini-vision-scan/index.ts` | Edge handler, prompt/schema, response cleanup |
| `supabase/functions/gemini-vision-scan/gemini_client.ts` | Model attempts, timeout, retry/failover |
| `supabase/functions/gemini-vision-scan/gemini_model_health.ts` | Health read/write best effort |
| `supabase/functions/gemini-vision-scan/bounding_box.ts` | Center-preserving box shrink |
| `supabase/migrations/20260815141623_add_gemini_model_health.sql` | Health table/RPC/RLS/grants |

### 16.4 Overlay geometry

| File | Trách nhiệm |
| --- | --- |
| `lib/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart` | Image load/cache/composition/painter/hit-test |
| `lib/features/vocab_scan/domain/image_rect_calculator.dart` | contain-fit và normalized box transform |
| `lib/features/vocab_scan/domain/forbidden_zone_builder.dart` | Inflated object exclusion zones |
| `lib/features/vocab_scan/domain/label_size_measurer.dart` | Text/card/badge footprint measurement |
| `lib/features/vocab_scan/domain/label_unit_geometry.dart` | Card/badge/sticker component geometry |
| `lib/features/vocab_scan/domain/label_candidate_generator.dart` | Ring/angle candidates |
| `lib/features/vocab_scan/domain/label_angle_ranker.dart` | Openness + center bias |
| `lib/features/vocab_scan/domain/label_placement_solver.dart` | MRV + fallback tiers |
| `lib/features/vocab_scan/domain/label_connector_geometry.dart` | Connector route/collision math |
| `lib/features/vocab_scan/presentation/label_connector_painter.dart` | Dashed curves/arrows |

### 16.5 Placeholder/dead-end source

| File | Hiện trạng |
| --- | --- |
| `presentation/widgets/note_template_selector.dart` | `SizedBox.shrink`, TODO |
| `presentation/screens/storage_album_screen.dart` | Coming soon UI |
| `presentation/screens/selected_vocab_screen.dart` | Placeholder text |
| `domain/entities/vocab_entity.dart` | Empty entity |
| `domain/entities/photo_note_entity.dart` | Empty entity |

Các path rút gọn trong bảng trên nằm dưới `lib/features/ai_scan/`.

## 17. Test map

### 17.1 Flutter tests trực tiếp của scan

| Test file | Bao phủ chính |
| --- | --- |
| `test/features/ai_scan/photo_scan_bottom_sheet_test.dart` | picker mapping, pipeline, preview, lỗi, web capture, fullscreen |
| `test/features/ai_scan/camera_capture_view_test.dart` | camera lifecycle, permission/no-device/error/switch camera |
| `test/features/ai_scan/scan_provider_test.dart` | read -> Vision -> save ordering và failure |
| `test/features/ai_scan/scan_flow_controller_test.dart` | optional navigation + error dialog |
| `test/features/ai_scan/scan_image_compressor_web_test.dart` | JPEG web < 300 KiB |
| `test/core/services/gemini_vision_service_test.dart` | endpoint/auth/request/parser/ranking/errors/bounds |
| `test/features/ai_scan/vocab_canvas_overlay_test.dart` | transform/cache/hit-test/fallback/performance/goldens |

### 17.2 Geometry tests

`test/features/vocab_scan/` có unit/golden tests cho:

- forbidden zones;
- angle ranking;
- candidate generation;
- connector intersections/routes;
- label measurement/unit geometry;
- MRV placement và fallback;
- connector painter.

### 17.3 Edge tests

`supabase/functions/gemini-vision-scan/`:

- `gemini_client_test.ts`: model order, 503 retry, failover, timeout, health
  prioritization, client-status exclusions.
- `bounding_box_test.ts`: default/custom shrink, center, boundary, malformed box,
  ratio validation.

### 17.4 Lệnh verification khuyến nghị

Narrow Flutter flow:

```powershell
flutter test test/features/ai_scan/photo_scan_bottom_sheet_test.dart `
  test/features/ai_scan/scan_provider_test.dart `
  test/core/services/gemini_vision_service_test.dart
```

Toàn bộ scan + geometry:

```powershell
flutter test test/features/ai_scan test/features/vocab_scan `
  test/core/services/gemini_vision_service_test.dart
```

Static checks:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
```

Edge tests khi máy có Deno:

```powershell
deno test supabase/functions/gemini-vision-scan/bounding_box_test.ts `
  supabase/functions/gemini-vision-scan/gemini_client_test.ts
```

Máy lập handoff hiện không có `deno` trong PATH; không được tuyên bố Edge tests
pass nếu chưa chạy trong môi trường có Deno.

Golden tests có thể tạo artifact diff trong
`test/features/ai_scan/failures/`; không xóa artifact người khác khi chưa xác
định ownership.

## 18. Checklist cho agent tiếp quản

Trước khi sửa:

1. Đọc `AGENTS.md`.
2. Đọc tài liệu này, rồi xác nhận lại các file trực tiếp liên quan thay đổi.
3. Xác định UX đích là inline result hay `/scan-overlay` navigation.
4. Xác định target platform; web/native có persistence và camera khác nhau.
5. Kiểm tra working tree, không ghi đè artifact hoặc thay đổi của người khác.
6. Nếu sửa API contract, cập nhật đồng thời:
   - Edge response schema/prompt;
   - Edge cleanup;
   - `GeminiVisionResult`/`VocabDetection` parser + serializer;
   - SQLite JSON compatibility;
   - overlay expectations;
   - Flutter + Deno tests.
7. Nếu đổi giới hạn từ, đồng bộ server 12/client 15/solver/golden tests.
8. Nếu sửa bounding box, nhớ pipeline đang shrink đúng một lần ở Edge; không
   shrink lần hai ở Flutter.
9. Nếu hiện thực album, cần thiết kế migration/read API/file cleanup/user
   ownership/web persistence trước khi nối UI.
10. Nếu bật label tap/TTS, truyền callback từ screen; không đặt audio side effect
    trong painter.
11. Nếu thêm cancellation, xử lý cả HTTP, lifecycle và cleanup file/record.
12. Xác minh permission/runner files trên thiết bị thật trước release native.

## 19. Regression checklist theo hành vi

- Camera và gallery đều hội tụ vào cùng pipeline sau `PickedScanImage`.
- Cancel picker không hiện dialog lỗi.
- Preview gốc xuất hiện trước khi nén xong.
- Preview đổi sang compressed JPEG trước Vision.
- Không gọi Vision khi compress/store thất bại.
- Không lưu result khi Vision thất bại.
- Access token không tồn tại thì không gửi HTTP.
- JPEG <= 300 KiB và Base64 dưới Edge limit.
- Response 200 sai schema không bị coi là empty success.
- Duplicate word giữ detection có box lớn nhất.
- Coordinate chạm biên phải/dưới hợp lệ; tràn biên bị reject.
- Bounding box không bị shrink hai lần.
- Tối đa 12 từ từ Edge vẫn render ổn; client tolerance 15 không regress.
- Resize/zoom không recompute placement không cần thiết.
- Solver lỗi fallback bbox-only, không crash.
- Fullscreen biến đổi ảnh và overlay cùng nhau.
- Web camera dispose media tracks khi đóng.
- Error dialog giữ đúng message chuyên biệt.
- Không tuyên bố album/TTS/template hoạt động khi chưa nối end-to-end.

## 20. Ưu tiên kỹ thuật nếu tiếp tục phát triển

Đây là backlog được suy ra từ khoảng trống source, **không phải quyền tự động
thay đổi sản phẩm**:

1. Chốt UX kết quả inline hay route riêng và loại bỏ đường đi mâu thuẫn.
2. Hoàn thiện native runner/permissions và test trên thiết bị thật.
3. Bổ sung query/migration/delete/retention cho album local.
4. Xử lý orphan JPEG và atomicity giữa file/result record.
5. Thiết kế web persistence nếu Thư viện phải hoạt động trên web.
6. Nối template selection vào style config hoặc loại bỏ UI giả.
7. Nối label tap/TTS theo quyết định UX/accessibility.
8. Thêm cancellation hoặc khóa dismiss trong phase xử lý.
9. Xác nhận JWT enforcement khi deploy Edge Function.
10. Cập nhật README/comment model để không còn mô tả Gemini 1.5 cũ.

Mỗi mục trên có thể thay đổi behavior/data/security và phải được người dùng hoặc
spec phê duyệt trước khi implementation.
