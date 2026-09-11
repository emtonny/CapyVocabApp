import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/storage_service.dart';
import '../../application/library_sync_gateway.dart';
import '../../domain/entities/library_cloud_delta.dart';
import '../../domain/entities/library_enums.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/normalized_bounding_box.dart';
import '../../domain/entities/photo_note.dart';
import '../../domain/entities/photo_note_snapshot.dart';
import '../../domain/entities/photo_note_purge_target.dart';
import '../../domain/entities/scan_models.dart';

typedef LocalMediaFileResolver = Future<File> Function(String relativePath);

/// Supabase implementation of the normalized M3A Library contract.
final class SupabaseLibrarySyncGateway implements LibraryRuntimeGateway {
  SupabaseLibrarySyncGateway({
    required SupabaseClient client,
    required LocalMediaFileResolver resolveLocalMedia,
  })  : _client = client,
        _storage = StorageService(supabaseClient: client),
        _resolveLocalMedia = resolveLocalMedia;

  final SupabaseClient _client;
  final StorageService _storage;
  final LocalMediaFileResolver _resolveLocalMedia;

  @override
  String? get authenticatedUserId => _client.auth.currentUser?.id;

  @override
  Future<LibraryCloudDelta> pullLibraryDelta({
    required String userId,
    required int afterCursor,
    int limit = 100,
  }) async {
    if (authenticatedUserId != userId) {
      throw const LibrarySyncFailure.auth('pull_auth_required');
    }
    if (afterCursor < 0 || limit <= 0 || limit > 500) {
      throw const LibrarySyncFailure.contract('invalid_pull_request');
    }
    final raw = await _client.rpc('pull_library_delta', params: {
      'p_after_sequence': afterCursor,
      'p_limit': limit,
    });
    if (raw is! Map) {
      throw const LibrarySyncFailure.contract('invalid_pull_response');
    }
    try {
      return decodeLibraryCloudDelta(
        Map<String, Object?>.from(raw),
        userId: userId,
        previousCursor: afterCursor,
      );
    } catch (_) {
      throw const LibrarySyncFailure.contract('invalid_pull_response');
    }
  }

  @override
  Future<MediaRemotePaths> uploadMedia(MediaAsset asset) async {
    final display = await _upload(
      asset: asset,
      relativePath: asset.displayRelativePath,
      variant: PhotoNoteMediaVariant.display,
    );
    final original = asset.originalRelativePath == null
        ? null
        : await _upload(
            asset: asset,
            relativePath: asset.originalRelativePath!,
            variant: PhotoNoteMediaVariant.original,
          );
    final modelInput = asset.modelInputRelativePath == null
        ? null
        : await _upload(
            asset: asset,
            relativePath: asset.modelInputRelativePath!,
            variant: PhotoNoteMediaVariant.modelInput,
          );
    return MediaRemotePaths(
      original: original,
      display: display,
      modelInput: modelInput,
    );
  }

  Future<String> _upload({
    required MediaAsset asset,
    required String relativePath,
    required PhotoNoteMediaVariant variant,
  }) async {
    final file = await _resolveLocalMedia(relativePath);
    if (!await file.exists()) {
      throw const LibrarySyncFailure.contract('local_media_missing');
    }
    return _storage.uploadPhotoNoteImage(
      imageFile: file,
      userId: asset.userId,
      mediaAssetId: asset.id,
      variant: variant,
      extension: _extension(relativePath, asset.mimeType),
    );
  }

  @override
  Future<void> upsertMediaAsset(
    MediaAsset asset,
    MediaRemotePaths remotePaths,
  ) async {
    await _client.from('media_assets').upsert({
      'id': asset.id,
      'user_id': asset.userId,
      'content_hash_sha256': asset.contentHashSha256,
      'original_object_path': remotePaths.original,
      'display_object_path': remotePaths.display,
      'model_input_object_path': remotePaths.modelInput,
      'mime_type': asset.mimeType,
      'width': asset.width,
      'height': asset.height,
      'orientation': asset.orientation,
      'byte_size_original': asset.byteSizeOriginal,
      'byte_size_display': asset.byteSizeDisplay,
      'preprocessing_version': asset.preprocessingVersion,
      'capture_source': _enumValue(asset.captureSource),
      'captured_at': asset.capturedAt?.toIso8601String(),
      'created_at': asset.createdAt.toIso8601String(),
      'updated_at': asset.createdAt.toIso8601String(),
      'deleted_at': asset.deletedAt?.toIso8601String(),
      'sync_version': 1,
    }, onConflict: 'id');
  }

  @override
  Future<void> upsertScanRun(ScanRun scanRun) async {
    await _client.from('scan_runs').upsert({
      'id': scanRun.id,
      'user_id': scanRun.userId,
      'media_asset_id': scanRun.mediaAssetId,
      'request_id': scanRun.requestId,
      'provider': scanRun.provider,
      'model_name': scanRun.modelName,
      'model_version': scanRun.modelVersion,
      'service_tier': scanRun.serviceTier,
      'prompt_version': scanRun.promptVersion,
      'response_schema_version': scanRun.responseSchemaVersion,
      'preprocessing_version': scanRun.preprocessingVersion,
      'raw_response_json': scanRun.rawResponseJson,
      'response_hash_sha256': scanRun.responseHashSha256,
      'status': _enumValue(scanRun.status),
      'error_code': scanRun.errorCode,
      'started_at': scanRun.startedAt.toIso8601String(),
      'completed_at': scanRun.completedAt?.toIso8601String(),
      'created_at': scanRun.startedAt.toIso8601String(),
      'updated_at':
          (scanRun.completedAt ?? scanRun.startedAt).toIso8601String(),
      'sync_version': 1,
    }, onConflict: 'id');
  }

  @override
  Future<void> upsertVocabDetection({
    required String userId,
    required VocabDetection detection,
  }) async {
    await _client.from('vocab_detections').upsert({
      'id': detection.id,
      'user_id': userId,
      'scan_run_id': detection.scanRunId,
      'word_raw': detection.wordRaw,
      'word_normalized': detection.wordNormalized,
      'phonetic': detection.phonetic,
      'meaning_vi': detection.meaningVi,
      'part_of_speech': detection.partOfSpeech,
      'example_en': detection.exampleEn,
      'example_vi': detection.exampleVi,
      'bbox_x': detection.boundingBox?.x,
      'bbox_y': detection.boundingBox?.y,
      'bbox_width': detection.boundingBox?.width,
      'bbox_height': detection.boundingBox?.height,
      'confidence': detection.confidence,
      'display_order': detection.displayOrder,
      'created_at': detection.createdAt.toIso8601String(),
    }, onConflict: 'id');
  }

  @override
  Future<void> upsertVocabAnnotation(VocabAnnotation annotation) async {
    await _client.from('vocab_annotations').upsert({
      'id': annotation.id,
      'user_id': annotation.userId,
      'detection_id': annotation.detectionId,
      'source': _enumValue(annotation.source),
      'quality_status': _enumValue(annotation.qualityStatus),
      'corrected_word': annotation.correctedWord,
      'corrected_phonetic': annotation.correctedPhonetic,
      'corrected_meaning_vi': annotation.correctedMeaningVi,
      'corrected_bbox_x': annotation.correctedBoundingBox?.x,
      'corrected_bbox_y': annotation.correctedBoundingBox?.y,
      'corrected_bbox_width': annotation.correctedBoundingBox?.width,
      'corrected_bbox_height': annotation.correctedBoundingBox?.height,
      'revision': annotation.revision,
      'created_at': annotation.createdAt.toIso8601String(),
      'updated_at': annotation.updatedAt.toIso8601String(),
      'deleted_at': annotation.deletedAt?.toIso8601String(),
    }, onConflict: 'id');
  }

  @override
  Future<void> upsertPhotoNote({
    required PhotoNote photoNote,
    required String displayObjectPath,
  }) async {
    await _client.from('photo_notes').upsert({
      'id': photoNote.id,
      'user_id': photoNote.userId,
      'image_path': displayObjectPath,
      'media_asset_id': photoNote.mediaAssetId,
      'primary_scan_run_id': photoNote.primaryScanRunId,
      'template_id': photoNote.templateId,
      'note_title': photoNote.title,
      'emoji': photoNote.emoji,
      'created_at': photoNote.createdAt.toIso8601String(),
      'updated_at': photoNote.updatedAt.toIso8601String(),
      'deleted_at': photoNote.deletedAt?.toIso8601String(),
      'sync_version': 1,
    }, onConflict: 'id');
  }

  @override
  Future<void> purgePhotoNote(PhotoNotePurgeTarget target) async {
    final userId = target.userId;
    final photoNoteId = target.photoNoteId;
    await _client
        .from('photo_notes')
        .delete()
        .eq('id', photoNoteId)
        .eq('user_id', userId);

    final remaining = await _client
        .from('photo_notes')
        .select('id')
        .eq('user_id', userId)
        .eq('media_asset_id', target.mediaAssetId)
        .limit(1);
    if (remaining.isNotEmpty) return;

    await _client
        .from('media_assets')
        .delete()
        .eq('id', target.mediaAssetId)
        .eq('user_id', userId);

    final folder = '$userId/${target.mediaAssetId}';
    final listed = await _client.storage.from(StorageService.bucketName).list(
          path: folder,
        );
    final paths = listed
        .where((item) => item.name.isNotEmpty)
        .map((item) => '$folder/${item.name}')
        .toSet()
      ..addAll(target.remoteObjectPaths.where(
        (path) => path.startsWith('$folder/'),
      ));
    if (paths.isNotEmpty) {
      await _client.storage
          .from(StorageService.bucketName)
          .remove(paths.toList(growable: false));
    }
  }
}

LibraryCloudDelta decodeLibraryCloudDelta(
  Map<String, Object?> payload, {
  required String userId,
  required int previousCursor,
}) {
  final mediaRows = _rows(payload['media_assets']);
  final scanRows = _rows(payload['scan_runs']);
  final detectionRows = _rows(payload['vocab_detections']);
  final annotationRows = _rows(payload['vocab_annotations']);
  final noteRows = _rows(payload['photo_notes']);

  final mediaById = <String, MediaAsset>{};
  for (final row in mediaRows) {
    final id = row['id']! as String;
    final mimeType = row['mime_type']! as String;
    mediaById[id] = MediaAsset(
      id: id,
      userId: row['user_id']! as String,
      contentHashSha256: row['content_hash_sha256']! as String,
      displayRelativePath: 'capy_scans/cloud_$id.${_mimeExtension(mimeType)}',
      remoteOriginalPath: row['original_object_path'] as String?,
      remoteDisplayPath: row['display_object_path']! as String,
      mimeType: mimeType,
      width: (row['width']! as num).toInt(),
      height: (row['height']! as num).toInt(),
      orientation: (row['orientation']! as num).toInt(),
      byteSizeOriginal: (row['byte_size_original'] as num?)?.toInt(),
      byteSizeDisplay: (row['byte_size_display']! as num).toInt(),
      preprocessingVersion: row['preprocessing_version']! as String,
      captureSource: _decodeEnum(CaptureSource.values, row['capture_source']),
      capturedAt: _nullableDate(row['captured_at']),
      createdAt: _date(row['created_at']),
      deletedAt: _nullableDate(row['deleted_at']),
      syncStatus: SyncStatus.synced,
    );
  }

  final scansById = <String, ScanRun>{};
  for (final row in scanRows) {
    final rawJson = row['raw_response_json'];
    scansById[row['id']! as String] = ScanRun(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      mediaAssetId: row['media_asset_id']! as String,
      requestId: row['request_id']! as String,
      provider: row['provider']! as String,
      modelName: row['model_name']! as String,
      modelVersion: row['model_version'] as String?,
      serviceTier: row['service_tier'] as String?,
      promptVersion: row['prompt_version']! as String,
      responseSchemaVersion: row['response_schema_version']! as String,
      preprocessingVersion: row['preprocessing_version']! as String,
      rawResponseJson:
          rawJson == null ? null : Map<String, Object?>.from(rawJson as Map),
      responseHashSha256: row['response_hash_sha256'] as String?,
      status: _decodeEnum(ScanRunStatus.values, row['status']),
      errorCode: row['error_code'] as String?,
      startedAt: _date(row['started_at']),
      completedAt: _nullableDate(row['completed_at']),
    );
  }

  final detectionsByScan = <String, List<VocabDetection>>{};
  for (final row in detectionRows) {
    final scanId = row['scan_run_id']! as String;
    final detection = VocabDetection(
      id: row['id']! as String,
      scanRunId: scanId,
      wordRaw: row['word_raw']! as String,
      wordNormalized: row['word_normalized']! as String,
      phonetic: row['phonetic'] as String?,
      meaningVi: row['meaning_vi'] as String?,
      partOfSpeech: row['part_of_speech'] as String?,
      exampleEn: row['example_en'] as String?,
      exampleVi: row['example_vi'] as String?,
      boundingBox: row['bbox_x'] == null
          ? null
          : NormalizedBoundingBox(
              x: (row['bbox_x']! as num).toDouble(),
              y: (row['bbox_y']! as num).toDouble(),
              width: (row['bbox_width']! as num).toDouble(),
              height: (row['bbox_height']! as num).toDouble(),
            ),
      confidence: (row['confidence'] as num?)?.toDouble(),
      displayOrder: (row['display_order']! as num).toInt(),
      createdAt: _date(row['created_at']),
    );
    detectionsByScan.putIfAbsent(scanId, () => []).add(detection);
  }

  final annotationsByDetection = <String, List<VocabAnnotation>>{};
  for (final row in annotationRows) {
    final detectionId = row['detection_id']! as String;
    final annotation = VocabAnnotation(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      detectionId: detectionId,
      source: _decodeEnum(AnnotationSource.values, row['source']),
      qualityStatus:
          _decodeEnum(AnnotationQualityStatus.values, row['quality_status']),
      correctedWord: row['corrected_word'] as String?,
      correctedPhonetic: row['corrected_phonetic'] as String?,
      correctedMeaningVi: row['corrected_meaning_vi'] as String?,
      correctedBoundingBox: row['corrected_bbox_x'] == null
          ? null
          : NormalizedBoundingBox(
              x: (row['corrected_bbox_x']! as num).toDouble(),
              y: (row['corrected_bbox_y']! as num).toDouble(),
              width: (row['corrected_bbox_width']! as num).toDouble(),
              height: (row['corrected_bbox_height']! as num).toDouble(),
            ),
      revision: (row['revision']! as num).toInt(),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      deletedAt: _nullableDate(row['deleted_at']),
    );
    annotationsByDetection.putIfAbsent(detectionId, () => []).add(annotation);
  }

  final snapshots = <PhotoNoteSnapshot>[];
  for (final row in noteRows) {
    final mediaId = row['media_asset_id']! as String;
    final media = mediaById[mediaId]!;
    final scanId = row['primary_scan_run_id'] as String?;
    final scan = scanId == null ? null : scansById[scanId];
    final detections = scanId == null
        ? const <VocabDetection>[]
        : (detectionsByScan[scanId] ?? const <VocabDetection>[])
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    snapshots.add(PhotoNoteSnapshot(
      photoNote: PhotoNote(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        mediaAssetId: mediaId,
        primaryScanRunId: scanId,
        title: row['note_title']! as String,
        emoji: row['emoji'] as String?,
        templateId: row['template_id']! as String,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        deletedAt: _nullableDate(row['deleted_at']),
        syncStatus: SyncStatus.synced,
      ),
      mediaAsset: media,
      primaryScanRun: scan,
      detections: detections,
      annotations: [
        for (final detection in detections)
          ...(annotationsByDetection[detection.id] ??
              const <VocabAnnotation>[]),
      ],
    ));
  }

  return LibraryCloudDelta(
    userId: userId,
    previousCursor: previousCursor,
    nextCursor: (payload['next_cursor']! as num).toInt(),
    hasMore: payload['has_more']! as bool,
    snapshots: snapshots,
    deletions: _rows(payload['deletions']).map((row) {
      return LibraryCloudDeletion(
        userId: row['user_id']! as String,
        photoNoteId: row['photo_note_id']! as String,
        sequence: (row['sequence']! as num).toInt(),
        deletedAt: _date(row['changed_at']),
      );
    }),
  );
}

List<Map<String, Object?>> _rows(Object? value) {
  if (value is! List) throw const FormatException('Expected a row list');
  return value
      .map((row) => Map<String, Object?>.from(row as Map))
      .toList(growable: false);
}

T _decodeEnum<T extends Enum>(List<T> values, Object? raw) {
  for (final value in values) {
    if (_enumValue(value) == raw) return value;
  }
  throw FormatException('Unknown enum value: $raw');
}

DateTime _date(Object? value) => DateTime.parse(value! as String).toUtc();

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);

String _mimeExtension(String mimeType) => switch (mimeType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => throw const FormatException('Unsupported cloud media MIME type'),
    };

String _enumValue(Enum value) => value.name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );

String _extension(String relativePath, String mimeType) {
  final fileName = relativePath.replaceAll('\\', '/').split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot >= 0 && dot < fileName.length - 1) {
    return fileName.substring(dot + 1).toLowerCase();
  }
  return switch (mimeType.trim().toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    _ => throw const LibrarySyncFailure.contract('media_extension_missing'),
  };
}
