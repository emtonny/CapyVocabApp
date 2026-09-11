# Data Contract cho Thư viện Offline-first và ML-ready

> Luồng pull metadata đa thiết bị và quy tắc không tự tải ảnh được chốt tại
> [m4_cloud_metadata_pull.md](m4_cloud_metadata_pull.md).

> Trạng thái: **DRAFT — chờ duyệt**  
> Phiên bản contract: `0.1.0-draft`  
> Kiến trúc liên quan: `../architecture/offline_ml_storage.md`  
> Privacy/retention: `privacy_and_retention.md`

## 1. Mục đích

Tài liệu định nghĩa ý nghĩa dữ liệu độc lập với SQLite, Supabase hoặc một ML
runtime cụ thể. M1 sẽ chuyển contract này thành Dart entities/interfaces; M2 mới
quyết định physical schema và migration.

## 2. Quy ước chung

- ID đồng bộ: UUID biểu diễn bằng string canonical.
- Timestamp: UTC ISO-8601 ở boundary, timezone-aware timestamp trên PostgreSQL.
- Local path: relative path dưới app-private root; không lưu absolute path làm
  identity.
- Cloud media: lưu object path, không lưu public URL lâu dài.
- JSON có `schema_version` và phải bảo toàn raw payload.
- Soft delete dùng `deleted_at`; không dùng riêng boolean `is_deleted`.
- `created_at` bất biến; `updated_at` tăng đơn điệu theo logical update.
- Mọi entity thuộc user phải có `user_id` hoặc suy ra owner qua parent với
  foreign key không mơ hồ.
- Không lưu secret, access token, refresh token hoặc API key trong các bảng này.

## 3. Versioning và compatibility

Ba version tách biệt:

| Version | Ý nghĩa |
| --- | --- |
| `database_schema_version` | Physical local/cloud schema |
| `response_schema_version` | Contract raw JSON từ AI |
| `feature_schema_version` | Cách biến raw data thành model features |

Thêm field optional là backward-compatible. Đổi type/meaning, xóa field hoặc
thay preprocessing phải tăng version và có adapter/migration. Payload version
không biết phải được giữ raw và đưa vào quarantine; không tự đoán.

## 4. Entity contracts

### 4.1 LocalAccount

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `user_id` | UUID | No | Khớp Supabase auth user khi có account |
| `account_state` | enum | No | `active`, `locked`, `pending_purge` |
| `last_authenticated_at` | timestamp | Yes | Không dùng thay server auth |
| `cloud_backup_enabled` | bool | No | Consent độc lập |
| `local_personalization_enabled` | bool | No | Consent độc lập |
| `federated_contribution_enabled` | bool | No | Mặc định false |
| `created_at` | timestamp | No | UTC |
| `updated_at` | timestamp | No | UTC |

### 4.2 MediaAsset

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id` | UUID | No | Identity chung local/cloud |
| `user_id` | UUID | No | Owner |
| `content_hash_sha256` | string | No | Hash bytes của variant gốc được quản lý |
| `original_relative_path` | string | Yes | Có nếu policy D2 giữ original |
| `display_relative_path` | string | No | Bắt buộc để xem offline sau commit |
| `model_input_relative_path` | string | Yes | Có khi preprocessing thành công |
| `remote_original_path` | string | Yes | Object path, không phải public URL |
| `remote_display_path` | string | Yes | Object path |
| `mime_type` | string | No | MIME đã validate |
| `width` / `height` | int | No | Số dương |
| `orientation` | int/enum | No | Orientation đã normalize/ghi nhận |
| `byte_size_original` | int | Yes | Không âm |
| `byte_size_display` | int | No | Không âm |
| `preprocessing_version` | string | No | Pipeline tạo model-input/display |
| `capture_source` | enum | No | `camera`, `gallery`, `imported`, `migration` |
| `captured_at` | timestamp | Yes | Từ source, không tin cậy tuyệt đối |
| `created_at` | timestamp | No | Thời điểm ingest |
| `deleted_at` | timestamp | Yes | Soft deletion |
| `sync_status` | enum | No | Xem state machine |

### 4.3 PhotoNote

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id` | UUID | No | Client-generated |
| `user_id` | UUID | No | Owner |
| `media_asset_id` | UUID | No | FK MediaAsset |
| `primary_scan_run_id` | UUID | Yes | Scan đang dùng cho UI |
| `title` | string | No | Trim, giới hạn độ dài tại validation layer |
| `emoji` | string | Yes | Presentation metadata, không phải ML label |
| `template_id` | string | No | Default có version rõ ràng |
| `created_at` | timestamp | No | Dùng lọc ngày |
| `updated_at` | timestamp | No | Conflict resolution |
| `deleted_at` | timestamp | Yes | Null nếu active |
| `sync_status` | enum | No | Local/cloud lifecycle |

`vocab_count` và chips không phải source field; chúng được derive từ detection
hoặc annotation active để tránh sai lệch.

### 4.4 ScanRun

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id` | UUID | No | Identity của một lần scan |
| `user_id` | UUID | No | Owner |
| `media_asset_id` | UUID | No | Input media |
| `request_id` | string/UUID | No | Unique idempotency key |
| `provider` | string | No | Ví dụ `google_gemini` |
| `model_name` | string | No | Model thực tế đã dùng |
| `model_version` | string | Yes | Nếu provider cung cấp |
| `service_tier` | string | Yes | Provenance/operations, không làm label |
| `prompt_version` | string | No | Bắt buộc cho reproducibility |
| `response_schema_version` | string | No | Bắt buộc |
| `preprocessing_version` | string | No | Input transform |
| `raw_response_json` | JSON | No với success | Bất biến |
| `response_hash_sha256` | string | No với success | Detect corruption/change |
| `status` | enum | No | `pending`, `succeeded`, `failed`, `quarantined` |
| `error_code` | string | Yes | Không chứa secret/raw PII |
| `started_at` / `completed_at` | timestamp | No/Yes | Latency/provenance |

Không update raw response của một ScanRun. Scan lại tạo ScanRun mới.

### 4.5 VocabDetection

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id` | UUID | No | Detection identity |
| `scan_run_id` | UUID | No | FK ScanRun |
| `word_raw` | string | No | Output gốc |
| `word_normalized` | string | No | Search/dedupe key có normalizer version |
| `phonetic` | string | Yes | AI prediction |
| `meaning_vi` | string | Yes | AI prediction |
| `part_of_speech` | string | Yes | Không tự suy ra nếu thiếu |
| `example_en` / `example_vi` | string | Yes | Có provenance |
| `bbox_x/y/width/height` | decimal | Yes | Hệ tọa độ và range do schema định nghĩa |
| `confidence` | decimal | Yes | Không giả `0` nếu provider không trả |
| `display_order` | int | No | Số không âm |
| `created_at` | timestamp | No | UTC |

Detection là prediction, không phải ground truth và không được chỉnh sửa trực
tiếp.

### 4.6 VocabAnnotation

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id` | UUID | No | Annotation identity |
| `user_id` | UUID | No | Người xác nhận/sửa |
| `detection_id` | UUID | No | Prediction nguồn |
| `source` | enum | No | `user_confirmed`, `user_corrected`, `imported` |
| `quality_status` | enum | No | `accepted`, `corrected`, `rejected` |
| `corrected_word` | string | Yes | Có khi corrected |
| `corrected_phonetic` | string | Yes | Không bắt buộc |
| `corrected_meaning_vi` | string | Yes | Không bắt buộc |
| `corrected_bbox_json` | JSON | Yes | Có schema/version |
| `revision` | int | No | Tăng đơn điệu |
| `created_at` / `updated_at` | timestamp | No | Audit |
| `deleted_at` | timestamp | Yes | Không hard-delete history ngay |

Giá trị effective cho UI: user correction mới nhất hợp lệ, sau đó user
confirmation, cuối cùng mới fallback AI prediction.

### 4.7 Album và AlbumPhotoNote

`Album`:

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id`, `user_id` | UUID | No | Owner-scoped |
| `name` | string | No | Trim, không rỗng |
| `icon` | string | No | Emoji/icon key |
| `is_favorite` | bool | No | Default false |
| `created_at`, `updated_at` | timestamp | No | UTC |
| `deleted_at` | timestamp | Yes | Xóa Album không xóa Photo |
| `sync_status` | enum | No | Lifecycle |

`AlbumPhotoNote`:

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `album_id`, `photo_note_id` | UUID | No | Composite unique relation |
| `added_at` | timestamp | No | UTC |
| `removed_at` | timestamp | Yes | Operation/tombstone semantics |
| `operation_id` | UUID | No | Idempotent sync |

### 4.8 LearningEvent

LearningEvent là append-only evidence cho SRS và personalization.

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id`, `user_id` | UUID | No | Owner-scoped |
| `vocab_annotation_id` | UUID | Yes | Ưu tiên label đã xác nhận |
| `detection_id` | UUID | Yes | Fallback provenance |
| `photo_note_id`, `session_id` | UUID | Yes/No | Context/session |
| `event_type` | enum | No | `shown`, `answered`, `hinted`, `skipped`, ... |
| `answer_normalized` | string | Yes | Chỉ lưu nếu cần cho task |
| `is_correct` | bool | Yes | Label hành vi |
| `response_time_ms` | int | Yes | Không âm, cap outlier ở feature layer |
| `hint_count`, `attempt_number` | int | Yes | Không âm |
| `mastery_before`, `mastery_after` | decimal | Yes | Có algorithm version |
| `scheduler_version` | string | No | Tránh training-serving skew |
| `model_version_id` | UUID | Yes | Model đã ảnh hưởng lựa chọn |
| `occurred_at` | timestamp | No | Event time |
| `recorded_at` | timestamp | No | Ingest time |

Không update LearningEvent cũ. Correction tạo compensating event có reference.

### 4.9 SrsProgress

SRS progress là materialized state có thể rebuild từ ordered LearningEvents.

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `user_id`, `vocab_key` | UUID/string | No | Composite identity |
| `mastery_level` | decimal/int | No | Theo scheduler version |
| `review_count` | int | No | Không âm |
| `last_reviewed_at`, `next_review_at` | timestamp | Yes/No | UTC |
| `scheduler_version` | string | No | Rebuild contract |
| `updated_at` | timestamp | No | Sync/conflict |

### 4.10 SyncOperation và Tombstone

`SyncOperation`:

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `operation_id` | UUID | No | Idempotency key |
| `user_id` | UUID | No | Queue partition |
| `entity_type`, `entity_id` | enum/UUID | No | Target |
| `operation_type` | enum | No | create/update/delete/upload/relation |
| `payload_json` | JSON | No | Versioned payload |
| `dependency_ids` | list/JSON | Yes | Media/parent ordering |
| `state` | enum | No | pending/running/retry/blocked/done |
| `attempt_count` | int | No | Không âm |
| `next_attempt_at` | timestamp | Yes | Backoff |
| `last_error_code` | string | Yes | Redacted |
| `created_at`, `updated_at` | timestamp | No | UTC |

Tombstone giữ entity ID, owner, deletion version/time và remote purge status để
update cũ không làm sống lại dữ liệu đã xóa.

### 4.11 TrainingExample và DatasetManifest

`TrainingExample` là projection derived; có thể xóa và tái dựng.

| Field | Type | Null | Quy tắc |
| --- | --- | --- | --- |
| `id`, `user_id` | UUID | No | Owner-scoped |
| `task_type` | enum | No | SRS/vision/rerank/... |
| `media_asset_id` | UUID | Yes | Input provenance |
| `source_detection_id` | UUID | Yes | Prediction nguồn |
| `source_annotation_id` | UUID | Yes | Label nguồn |
| `feature_schema_version` | string | No | Bắt buộc |
| `label_schema_version` | string | No | Bắt buộc |
| `builder_version` | string | No | Reproducibility |
| `features_json` / `target_json` | JSON | No | Platform-neutral contract |
| `eligibility_status` | enum | No | eligible/excluded/quarantined |
| `quality_score` | decimal | Yes | Không thay label source |
| `split` | enum | No | train/validation/test/excluded |
| `split_seed_version` | string | No | Deterministic split |
| `created_at` | timestamp | No | UTC |

DatasetManifest lưu builder/config version, source watermark, counts, hashes,
split statistics, consent snapshot và quality report.

### 4.12 ModelVersion, TrainingRun và TrainingRunExample

`ModelVersion` giữ base model ID/version, task, feature/label schema, checkpoint
relative path, activation status và baseline/personalized metrics.

`TrainingRun` giữ model version, dataset manifest, start/end, sample count,
epochs/steps, metrics, device/runtime metadata không định danh và trạng thái.

`TrainingRunExample` là bảng nối bắt buộc giữa training run và example. Nó phục
vụ audit, thu hồi consent và rebuild/unlearning.

## 5. Relationships

```text
LocalAccount 1 --- N MediaAsset
MediaAsset   1 --- N ScanRun
MediaAsset   1 --- N PhotoNote (thường 1, không ép ở contract draft)
ScanRun      1 --- N VocabDetection
VocabDetection 1 - N VocabAnnotation
PhotoNote    N --- N Album (qua AlbumPhotoNote)
Annotation/Detection 1 - N LearningEvent
Raw/Annotation/Event N - N TrainingExample (qua provenance refs)
DatasetManifest 1 --- N TrainingExample
TrainingRun N --- N TrainingExample (qua TrainingRunExample)
ModelVersion 1 --- N TrainingRun
```

## 6. State machines

### SyncStatus

```text
local_only -> pending -> syncing -> synced
                    \-> failed_retryable -> pending
                    \-> blocked_auth
                    \-> blocked_contract/quarantined
```

### Deletion

```text
active -> soft_deleted -> permanent_delete_pending -> purged
              \-> active (restore trước purge)
```

### Training eligibility

```text
unreviewed AI prediction -> excluded
user_confirmed/corrected + consent + valid media -> eligible
invalid/corrupt/unknown schema -> quarantined
deleted/consent revoked -> excluded
```

## 7. Normalization và dedupe draft

`word_normalized` đề xuất:

1. Unicode normalization xác định bằng `normalizer_version`.
2. Trim leading/trailing whitespace.
3. Collapse internal whitespace.
4. Locale-stable lowercase.
5. Không tự lemmatize hoặc bỏ dấu câu nếu chưa có task-specific rule.

Batch vocab dedupe dùng normalized word trong phạm vi session nhưng giữ toàn bộ
provenance tới các Photo Note nguồn. Không merge vĩnh viễn hai detection chỉ vì
word giống nhau.

## 8. Dataset split invariant

- Các crop/augmentation từ cùng `media_asset_id` phải cùng split.
- Split phải deterministic và có seed version.
- Example bị xóa/thu hồi consent không được xuất hiện trong manifest mới.
- Test set không dùng để chọn hyperparameter hoặc promotion threshold.
- Training và inference dùng cùng feature/preprocessing contract hoặc có adapter
  được test để tránh training-serving skew.

## 9. Migration compatibility với `scan_results`

M2 phải bảo toàn từng row hiện có:

- `local_path` -> MediaAsset migration source.
- `vocab_json` -> ScanRun raw response nguyên bản.
- `created_at` -> ingest timestamp.
- Integer legacy ID được lưu trong migration metadata, không dùng làm cloud ID.
- Parse lỗi không làm rollback toàn bộ migration; row được quarantine và raw
  JSON vẫn truy xuất được.

Không xóa `scan_results` trong migration đầu tiên.

## 10. Tiêu chí duyệt contract

- [ ] Mọi entity có owner và lifecycle.
- [ ] Raw evidence tách khỏi normalized/mutable data.
- [ ] User annotation tách khỏi AI prediction.
- [ ] Learning event append-only.
- [ ] Training example có provenance, version, consent và split.
- [ ] Không field nào phụ thuộc public URL hoặc absolute local path.
- [ ] Delete có thể lần theo training run/checkpoint.
- [ ] Contract biểu diễn được offline, sync retry và multi-device conflict.
- [ ] D1–D10 trong tài liệu kiến trúc đã được duyệt.
