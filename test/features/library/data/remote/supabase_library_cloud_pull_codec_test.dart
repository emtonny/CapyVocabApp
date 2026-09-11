import 'package:capy_vocab/features/library/data/remote/supabase_library_sync_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'a2000000-0000-0000-0000-000000000001';
const _mediaId = 'a2000000-0000-0000-0000-000000000002';
const _scanId = 'a2000000-0000-0000-0000-000000000003';
const _detectionId = 'a2000000-0000-0000-0000-000000000004';
const _annotationId = 'a2000000-0000-0000-0000-000000000005';
const _noteId = 'a2000000-0000-0000-0000-000000000006';
const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _time = '2026-09-10T02:00:00.000Z';

void main() {
  test('decodes normalized JSON while creating only a local target path', () {
    final delta = decodeLibraryCloudDelta({
      'next_cursor': 12,
      'has_more': false,
      'deletions': const <Object?>[],
      'media_assets': [
        {
          'id': _mediaId,
          'user_id': _userId,
          'content_hash_sha256': _sha,
          'original_object_path': null,
          'display_object_path': '$_userId/$_mediaId/display.jpg',
          'mime_type': 'image/jpeg',
          'width': 640,
          'height': 480,
          'orientation': 0,
          'byte_size_original': null,
          'byte_size_display': 1234,
          'preprocessing_version': 'vision-input-v1',
          'capture_source': 'camera',
          'captured_at': _time,
          'created_at': _time,
          'deleted_at': null,
        },
      ],
      'scan_runs': [
        {
          'id': _scanId,
          'user_id': _userId,
          'media_asset_id': _mediaId,
          'request_id': 'request-1',
          'provider': 'google_gemini',
          'model_name': 'gemini-flash',
          'model_version': null,
          'service_tier': 'free',
          'prompt_version': 'prompt-v1',
          'response_schema_version': 'response-v1',
          'preprocessing_version': 'vision-input-v1',
          'raw_response_json': {
            'words': [
              {'word': 'Cup'},
            ],
          },
          'response_hash_sha256': _sha,
          'status': 'succeeded',
          'error_code': null,
          'started_at': _time,
          'completed_at': _time,
        },
      ],
      'vocab_detections': [
        {
          'id': _detectionId,
          'scan_run_id': _scanId,
          'word_raw': 'Cup',
          'word_normalized': 'cup',
          'phonetic': null,
          'meaning_vi': 'cái cốc',
          'part_of_speech': 'noun',
          'example_en': null,
          'example_vi': null,
          'bbox_x': 0.1,
          'bbox_y': 0.2,
          'bbox_width': 0.3,
          'bbox_height': 0.4,
          'confidence': 0.9,
          'display_order': 0,
          'created_at': _time,
        },
      ],
      'vocab_annotations': [
        {
          'id': _annotationId,
          'user_id': _userId,
          'detection_id': _detectionId,
          'source': 'user_confirmed',
          'quality_status': 'accepted',
          'corrected_word': null,
          'corrected_phonetic': null,
          'corrected_meaning_vi': null,
          'corrected_bbox_x': null,
          'corrected_bbox_y': null,
          'corrected_bbox_width': null,
          'corrected_bbox_height': null,
          'revision': 1,
          'created_at': _time,
          'updated_at': _time,
          'deleted_at': null,
        },
      ],
      'photo_notes': [
        {
          'id': _noteId,
          'user_id': _userId,
          'media_asset_id': _mediaId,
          'primary_scan_run_id': _scanId,
          'note_title': 'Kitchen',
          'emoji': '🍵',
          'template_id': 'standard',
          'created_at': _time,
          'updated_at': _time,
          'deleted_at': null,
        },
      ],
    }, userId: _userId, previousCursor: 0);

    final snapshot = delta.snapshots.single;
    expect(delta.nextCursor, 12);
    expect(snapshot.mediaAsset.displayRelativePath,
        'capy_scans/cloud_$_mediaId.jpg');
    expect(snapshot.mediaAsset.remoteDisplayPath,
        '$_userId/$_mediaId/display.jpg');
    expect(snapshot.primaryScanRun!.rawResponseJson!['words'], hasLength(1));
    expect(snapshot.detections.single.wordNormalized, 'cup');
    expect(snapshot.annotations.single.id, _annotationId);
  });

  test('decodes retained hard-delete receipt without any aggregate', () {
    final delta = decodeLibraryCloudDelta({
      'next_cursor': 22,
      'has_more': false,
      'deletions': [
        {
          'sequence': 22,
          'user_id': _userId,
          'photo_note_id': _noteId,
          'changed_at': _time,
        },
      ],
      'media_assets': const <Object?>[],
      'scan_runs': const <Object?>[],
      'vocab_detections': const <Object?>[],
      'vocab_annotations': const <Object?>[],
      'photo_notes': const <Object?>[],
    }, userId: _userId, previousCursor: 12);

    expect(delta.snapshots, isEmpty);
    expect(delta.deletions.single.photoNoteId, _noteId);
    expect(delta.deletions.single.sequence, 22);
  });
}
