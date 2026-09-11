import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../library/data/local/sqlite_library_store.dart';
import '../../../library/data/local/sqlite_library_store_factory.dart';
import '../../../library/domain/library_domain.dart' as library_domain;
import '../services/scan_image_picker.dart';

typedef ScanUserIdProvider = String? Function();
typedef ScanImageSizeReader = Future<(int width, int height)> Function(
  Uint8List bytes,
);

final class ScanSaveRequest {
  const ScanSaveRequest({
    required this.localPath,
    required this.imageBytes,
    required this.result,
    required this.requestId,
    required this.captureSource,
    required this.templateId,
    required this.startedAt,
    required this.completedAt,
  });

  final String localPath;
  final Uint8List imageBytes;
  final GeminiVisionResult result;
  final String requestId;
  final ScanImageSource captureSource;
  final String templateId;
  final DateTime startedAt;
  final DateTime completedAt;
}

class ScanResultRecord {
  const ScanResultRecord({
    required this.id,
    required this.localPath,
    required this.vocabJson,
    required this.result,
    required this.createdAt,
    this.normalizedPhotoNoteId,
  });

  final int id;
  final String localPath;
  final String vocabJson;
  final GeminiVisionResult result;
  final DateTime createdAt;
  final String? normalizedPhotoNoteId;
}

abstract interface class ScanResultStore {
  Future<ScanResultRecord> save(ScanSaveRequest request);
}

class ScanResultLocalDataSource implements ScanResultStore {
  ScanResultLocalDataSource({
    Future<SqliteLibraryStore> Function()? openLibraryStore,
    ScanUserIdProvider? currentUserId,
    LibraryIdGenerator? idGenerator,
    ScanImageSizeReader? readImageSize,
  })  : _openLibraryStore = openLibraryStore ??
            (() => createDefaultSqliteLibraryStore(
                  idGenerator: createScanRequestId,
                )),
        _currentUserId =
            currentUserId ?? (() => SupabaseService.auth.currentUser?.id),
        _idGenerator = idGenerator ?? createScanRequestId,
        _readImageSize = readImageSize ?? _decodeImageSize;

  final Future<SqliteLibraryStore> Function() _openLibraryStore;
  final ScanUserIdProvider _currentUserId;
  final LibraryIdGenerator _idGenerator;
  final ScanImageSizeReader _readImageSize;
  Future<SqliteLibraryStore>? _libraryStoreFuture;

  Future<SqliteLibraryStore> get _libraryStore =>
      _libraryStoreFuture ??= _openLibraryStore();

  @override
  Future<ScanResultRecord> save(ScanSaveRequest request) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('An authenticated user is required to save a scan');
    }
    final createdAt = request.completedAt.toUtc();
    final rawResponse = Map<String, Object?>.from(
      request.result.rawResponseJson ?? request.result.toJson(),
    );
    final vocabJson = jsonEncode(rawResponse);
    final (width, height) = await _readImageSize(request.imageBytes);
    final mediaId = _idGenerator();
    final scanRunId = _idGenerator();
    final photoNoteId = _idGenerator();
    final detections = request.result.detectedVocabulary.indexed.map((entry) {
      final (index, detection) = entry;
      return library_domain.VocabDetection(
        id: _idGenerator(),
        scanRunId: scanRunId,
        wordRaw: detection.word,
        wordNormalized: detection.word.trim().toLowerCase(),
        phonetic: _nullableText(detection.phonetic),
        meaningVi: _nullableText(detection.meaning),
        partOfSpeech: _nullableText(detection.partOfSpeech),
        boundingBox: library_domain.NormalizedBoundingBox(
          x: detection.x,
          y: detection.y,
          width: detection.w,
          height: detection.h,
        ),
        displayOrder: index,
        createdAt: createdAt,
      );
    }).toList(growable: false);
    final snapshot = library_domain.PhotoNoteSnapshot(
      mediaAsset: library_domain.MediaAsset(
        id: mediaId,
        userId: userId,
        contentHashSha256: sha256.convert(request.imageBytes).toString(),
        displayRelativePath: _relativeScanPath(request.localPath),
        modelInputRelativePath: _relativeScanPath(request.localPath),
        mimeType: 'image/jpeg',
        width: width,
        height: height,
        orientation: 0,
        byteSizeDisplay: request.imageBytes.lengthInBytes,
        preprocessingVersion: 'scan-jpeg-v1',
        captureSource: request.captureSource == ScanImageSource.camera
            ? library_domain.CaptureSource.camera
            : library_domain.CaptureSource.gallery,
        capturedAt: createdAt,
        createdAt: createdAt,
        syncStatus: library_domain.SyncStatus.localOnly,
      ),
      primaryScanRun: library_domain.ScanRun(
        id: scanRunId,
        userId: userId,
        mediaAssetId: mediaId,
        requestId: request.requestId,
        provider: 'google_gemini',
        modelName: request.result.modelUsed ?? 'unknown-gemini-model',
        serviceTier: request.result.serviceTier,
        promptVersion: 'gemini-vision-hierarchy-v2-20260903',
        responseSchemaVersion: _responseSchemaVersion(rawResponse),
        preprocessingVersion: 'scan-jpeg-v1',
        rawResponseJson: rawResponse,
        responseHashSha256: sha256.convert(utf8.encode(vocabJson)).toString(),
        status: library_domain.ScanRunStatus.succeeded,
        startedAt: request.startedAt.toUtc(),
        completedAt: createdAt,
      ),
      photoNote: library_domain.PhotoNote(
        id: photoNoteId,
        userId: userId,
        mediaAssetId: mediaId,
        primaryScanRunId: scanRunId,
        title: _photoNoteTitle(request.result),
        templateId: request.templateId,
        createdAt: createdAt,
        updatedAt: createdAt,
        syncStatus: library_domain.SyncStatus.localOnly,
      ),
      detections: detections,
      annotations: const [],
    );
    final libraryStore = await _libraryStore;
    final id = await libraryStore.saveCapturedPhotoNoteWithLegacy(
      accountIfMissing: library_domain.LocalAccount(
        userId: userId,
        accountState: library_domain.AccountState.active,
        cloudBackupEnabled: false,
        localPersonalizationEnabled: false,
        federatedContributionEnabled: false,
        lastAuthenticatedAt: createdAt,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      snapshot: snapshot,
      legacyLocalPath: request.localPath,
      legacyVocabJson: vocabJson,
    );

    return ScanResultRecord(
      id: id,
      localPath: request.localPath,
      vocabJson: vocabJson,
      result: request.result,
      createdAt: createdAt,
      normalizedPhotoNoteId: photoNoteId,
    );
  }
}

class MemoryScanResultStore implements ScanResultStore {
  int _nextId = 1;

  @override
  Future<ScanResultRecord> save(ScanSaveRequest request) async {
    final createdAt = request.completedAt.toUtc();
    return ScanResultRecord(
      id: _nextId++,
      localPath: request.localPath,
      vocabJson: jsonEncode(
        request.result.rawResponseJson ?? request.result.toJson(),
      ),
      result: request.result,
      createdAt: createdAt,
    );
  }
}

Future<(int width, int height)> _decodeImageSize(Uint8List bytes) async {
  if (bytes.isEmpty) throw ArgumentError.value(bytes, 'imageBytes', 'is empty');
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

String _relativeScanPath(String localPath) {
  final normalized = localPath.trim().replaceAll('\\', '/');
  final filename = normalized.split('/').last;
  if (filename.isEmpty) {
    throw ArgumentError.value(localPath, 'localPath', 'has no filename');
  }
  return 'capy_scans/$filename';
}

String _responseSchemaVersion(Map<String, Object?> response) {
  final schema = response['schema_version'];
  return schema is int ? 'gemini-hierarchy-v$schema' : 'gemini-legacy-v1';
}

String _photoNoteTitle(GeminiVisionResult result) {
  if (result.detectedVocabulary.isEmpty) return 'Ảnh từ vựng';
  return result.detectedVocabulary
      .take(3)
      .map((detection) => detection.word.trim())
      .where((word) => word.isNotEmpty)
      .join(', ');
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
