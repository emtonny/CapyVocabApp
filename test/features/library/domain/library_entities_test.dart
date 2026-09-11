import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '00000000-0000-0000-0000-000000000001';
const _mediaId = '00000000-0000-0000-0000-000000000002';
const _photoNoteId = '00000000-0000-0000-0000-000000000003';
const _scanRunId = '00000000-0000-0000-0000-000000000004';
const _detectionId = '00000000-0000-0000-0000-000000000005';
const _annotationId = '00000000-0000-0000-0000-000000000006';
const _sha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

final _now = DateTime.utc(2026, 9, 1, 10);

void main() {
  group('core value invariants', () {
    test('normalizes UUIDs and rejects non-UTC timestamps', () {
      final note = _buildPhotoNote(
        id: _photoNoteId.toUpperCase(),
        primaryScanRunId: null,
      );

      expect(note.id, _photoNoteId);
      expect(
        () => _buildPhotoNote(
          primaryScanRunId: null,
          createdAt: DateTime(2026, 9, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => _buildPhotoNote(id: 'legacy-42', primaryScanRunId: null),
        throwsArgumentError,
      );
    });

    test('keeps normalized bounding boxes inside image bounds', () {
      expect(
        NormalizedBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        NormalizedBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
      );
      expect(
        () => NormalizedBoundingBox(
          x: 0.8,
          y: 0.1,
          width: 0.3,
          height: 0.2,
        ),
        throwsArgumentError,
      );
      expect(
        () => NormalizedBoundingBox(x: 0, y: 0, width: 0, height: 0.2),
        throwsArgumentError,
      );
    });

    test('accepts only SHA-256 digests and safe relative media paths', () {
      expect(
        () => _buildMediaAsset(contentHashSha256: 'not-a-hash'),
        throwsArgumentError,
      );
      expect(
        () => _buildMediaAsset(displayRelativePath: r'C:\Users\photo.jpg'),
        throwsArgumentError,
      );
      expect(
        () => _buildMediaAsset(
          displayRelativePath: 'https://cdn.example/photo.jpg',
        ),
        throwsArgumentError,
      );
      expect(
        () => _buildMediaAsset(displayRelativePath: '../photo.jpg'),
        throwsArgumentError,
      );
    });
  });

  group('raw scan evidence', () {
    test('succeeded scan requires raw response and its hash', () {
      expect(
        () => _buildScanRun(rawResponseJson: null, responseHashSha256: null),
        throwsArgumentError,
      );
    });

    test('deep-freezes raw Gemini JSON', () {
      final source = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'word': 'cup'},
        ],
      };
      final run = _buildScanRun(
        rawResponseJson: source,
        responseHashSha256: _sha256,
      );

      source['providerMutation'] = true;
      final frozen = run.rawResponseJson!;
      final items = frozen['items']! as List<Object?>;

      expect(frozen, isNot(contains('providerMutation')));
      expect(() => frozen['newKey'] = true, throwsUnsupportedError);
      expect(() => items.add('new item'), throwsUnsupportedError);
      expect(
        () => (items.single as Map<String, Object?>)['word'] = 'plate',
        throwsUnsupportedError,
      );
    });

    test('rejects non-finite values that cannot be serialized as JSON', () {
      expect(
        () => _buildScanRun(
          rawResponseJson: <String, Object?>{'confidence': double.nan},
          responseHashSha256: _sha256,
        ),
        throwsArgumentError,
      );
    });
  });

  group('offline Photo Note snapshot', () {
    test('contains a closed, internally consistent offline aggregate', () {
      final scanRun = _buildScanRun(
        rawResponseJson: const <String, Object?>{'word': 'cup'},
        responseHashSha256: _sha256,
      );
      final detection = _buildDetection();
      final annotation = _buildAnnotation();
      final snapshot = PhotoNoteSnapshot(
        photoNote: _buildPhotoNote(),
        mediaAsset: _buildMediaAsset(),
        primaryScanRun: scanRun,
        detections: [detection],
        annotations: [annotation],
      );

      expect(snapshot.vocabCount, 1);
      expect(snapshot.annotationsByDetectionId[_detectionId], [annotation]);
      expect(
        () => snapshot.detections.add(detection),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.annotationsByDetectionId[_detectionId]!.add(annotation),
        throwsUnsupportedError,
      );
    });

    test('rejects detection provenance from another scan run', () {
      final foreignDetection = _buildDetection(
        scanRunId: '00000000-0000-0000-0000-000000000099',
      );

      expect(
        () => PhotoNoteSnapshot(
          photoNote: _buildPhotoNote(),
          mediaAsset: _buildMediaAsset(),
          primaryScanRun: _buildScanRun(
            rawResponseJson: const <String, Object?>{'word': 'cup'},
            responseHashSha256: _sha256,
          ),
          detections: [foreignDetection],
          annotations: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate annotation identities', () {
      final annotation = _buildAnnotation();

      expect(
        () => PhotoNoteSnapshot(
          photoNote: _buildPhotoNote(),
          mediaAsset: _buildMediaAsset(),
          primaryScanRun: _buildScanRun(
            rawResponseJson: const <String, Object?>{'word': 'cup'},
            responseHashSha256: _sha256,
          ),
          detections: [_buildDetection()],
          annotations: [annotation, annotation],
        ),
        throwsArgumentError,
      );
    });
  });

  test('user-corrected annotation requires an explicit correction', () {
    expect(
      () => _buildAnnotation(
        source: AnnotationSource.userCorrected,
        correctedWord: null,
      ),
      throwsArgumentError,
    );

    final corrected = _buildAnnotation(
      source: AnnotationSource.userCorrected,
      correctedWord: 'mug',
    );
    expect(corrected.correctedWord, 'mug');
  });
}

MediaAsset _buildMediaAsset({
  String contentHashSha256 = _sha256,
  String displayRelativePath = 'accounts/1/media/display.jpg',
}) {
  return MediaAsset(
    id: _mediaId,
    userId: _userId,
    contentHashSha256: contentHashSha256,
    originalRelativePath: 'accounts/1/media/original.jpg',
    displayRelativePath: displayRelativePath,
    modelInputRelativePath: 'accounts/1/media/model.jpg',
    mimeType: 'image/jpeg',
    width: 1080,
    height: 1920,
    orientation: 0,
    byteSizeOriginal: 2048,
    byteSizeDisplay: 1024,
    preprocessingVersion: 'vision-input-v1',
    captureSource: CaptureSource.camera,
    capturedAt: _now,
    createdAt: _now,
    syncStatus: SyncStatus.localOnly,
  );
}

PhotoNote _buildPhotoNote({
  String id = _photoNoteId,
  String? primaryScanRunId = _scanRunId,
  DateTime? createdAt,
}) {
  return PhotoNote(
    id: id,
    userId: _userId,
    mediaAssetId: _mediaId,
    primaryScanRunId: primaryScanRunId,
    title: 'Kitchen',
    emoji: '🍵',
    templateId: 'default-v1',
    createdAt: createdAt ?? _now,
    updatedAt: createdAt ?? _now,
    syncStatus: SyncStatus.localOnly,
  );
}

ScanRun _buildScanRun({
  Map<String, Object?>? rawResponseJson,
  String? responseHashSha256,
}) {
  return ScanRun(
    id: _scanRunId,
    userId: _userId,
    mediaAssetId: _mediaId,
    requestId: 'scan-request-1',
    provider: 'gemini',
    modelName: 'gemini-flash',
    promptVersion: 'prompt-v1',
    responseSchemaVersion: 'scan-response-v1',
    preprocessingVersion: 'vision-input-v1',
    rawResponseJson: rawResponseJson,
    responseHashSha256: responseHashSha256,
    status: ScanRunStatus.succeeded,
    startedAt: _now,
    completedAt: _now.add(const Duration(seconds: 1)),
  );
}

VocabDetection _buildDetection({String scanRunId = _scanRunId}) {
  return VocabDetection(
    id: _detectionId,
    scanRunId: scanRunId,
    wordRaw: 'Cup',
    wordNormalized: 'cup',
    meaningVi: 'cái cốc',
    boundingBox: NormalizedBoundingBox(
      x: 0.1,
      y: 0.1,
      width: 0.2,
      height: 0.2,
    ),
    confidence: 0.9,
    displayOrder: 0,
    createdAt: _now,
  );
}

VocabAnnotation _buildAnnotation({
  AnnotationSource source = AnnotationSource.userConfirmed,
  String? correctedWord,
}) {
  return VocabAnnotation(
    id: _annotationId,
    userId: _userId,
    detectionId: _detectionId,
    source: source,
    qualityStatus: source == AnnotationSource.userCorrected
        ? AnnotationQualityStatus.corrected
        : AnnotationQualityStatus.accepted,
    correctedWord: correctedWord,
    revision: 1,
    createdAt: _now,
    updatedAt: _now,
  );
}
