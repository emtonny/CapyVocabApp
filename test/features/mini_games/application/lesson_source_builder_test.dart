import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/normalized_bounding_box.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_source_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '00000000-0000-4000-8000-000000000001';
const _otherUserId = '00000000-0000-4000-8000-000000000002';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test('freezes latest accepted corrections, bbox and deterministic revision',
      () {
    final snapshot = _snapshot(
      seed: 1,
      detections: [
        _DetectionSeed(word: 'Apple', box: _box(0.1)),
        _DetectionSeed(word: ' apple ', box: _box(0.2)),
        const _DetectionSeed(word: 'cup'),
        _DetectionSeed(word: 'book', box: _box(0.4)),
      ],
      annotations: [
        _AnnotationSeed(
          detectionIndex: 2,
          revision: 2,
          quality: AnnotationQualityStatus.corrected,
          correctedWord: 'Mug',
          correctedBox: _box(0.6),
        ),
        const _AnnotationSeed(
          detectionIndex: 3,
          revision: 1,
          quality: AnnotationQualityStatus.rejected,
        ),
      ],
    );

    final first = buildLessonSource(
      userId: _userId,
      snapshots: [snapshot],
      locallyAvailablePaths: {'capy_scans/1.jpg'},
      maxItems: 10,
    );
    final second = buildLessonSource(
      userId: _userId,
      snapshots: [snapshot],
      locallyAvailablePaths: {'capy_scans/1.jpg'},
      maxItems: 10,
    );

    expect(first.items.map((item) => item.answer), ['Apple', 'Mug']);
    expect(first.items.last.boundingBox.x, 0.6);
    expect(first.items.last.imageRelativePath, 'capy_scans/1.jpg');
    expect(
      first.exclusionCounts[LessonSourceExclusionReason.duplicateAnswer],
      1,
    );
    expect(
      first.exclusionCounts[LessonSourceExclusionReason.rejectedTarget],
      1,
    );
    expect(second.sourceRevisionHash, first.sourceRevisionHash);
    expect(second.items.last.sourceRevision, first.items.last.sourceRevision);
  });

  test('filters owner, deleted, missing-media and bbox-invalid sources', () {
    final valid = _snapshot(
      seed: 10,
      detections: [_DetectionSeed(word: 'apple', box: _box(0.1))],
    );
    final missingBox = _snapshot(
      seed: 20,
      detections: [const _DetectionSeed(word: 'cup')],
    );
    final wrongOwner = _snapshot(
      seed: 30,
      userId: _otherUserId,
      detections: [_DetectionSeed(word: 'book', box: _box(0.3))],
    );

    final result = buildLessonSource(
      userId: _userId,
      snapshots: [valid, missingBox, wrongOwner],
      locallyAvailablePaths: {
        'capy_scans/20.jpg',
        'capy_scans/30.jpg',
      },
      maxItems: 10,
    );

    expect(result.items, isEmpty);
    expect(
      result.exclusionCounts[LessonSourceExclusionReason.missingMedia],
      1,
    );
    expect(
      result.exclusionCounts[LessonSourceExclusionReason.missingBoundingBox],
      1,
    );
    expect(
      result.exclusionCounts[LessonSourceExclusionReason.ownerMismatch],
      1,
    );
  });

  test('loader reads owner-scoped snapshots and verifies local media',
      () async {
    final available = _snapshot(
      seed: 1,
      detections: [_DetectionSeed(word: 'apple', box: _box(0.1))],
    );
    final missing = _snapshot(
      seed: 2,
      detections: [_DetectionSeed(word: 'cup', box: _box(0.2))],
    );
    final repository = _FakeRepository({
      available.photoNote.id: available,
      missing.photoNote.id: missing,
    });
    final loader = LessonSourceLoader(
      repository: repository,
      mediaLoader: const _FakeMediaLoader({'capy_scans/1.jpg'}),
    );

    final result = await loader.load(
      userId: _userId,
      photoNoteIds: [
        missing.photoNote.id,
        available.photoNote.id,
        available.photoNote.id,
      ],
      maxItems: 10,
    );

    expect(result.items.map((item) => item.answer), ['apple']);
    expect(repository.requestedUserIds, {_userId});
    expect(repository.requestedPhotoNoteIds, hasLength(2));
    expect(
      result.exclusionCounts[LessonSourceExclusionReason.missingMedia],
      1,
    );
  });
}

final class _DetectionSeed {
  const _DetectionSeed({required this.word, this.box});

  final String word;
  final NormalizedBoundingBox? box;
}

final class _AnnotationSeed {
  const _AnnotationSeed({
    required this.detectionIndex,
    required this.revision,
    required this.quality,
    this.correctedWord,
    this.correctedBox,
  });

  final int detectionIndex;
  final int revision;
  final AnnotationQualityStatus quality;
  final String? correctedWord;
  final NormalizedBoundingBox? correctedBox;
}

PhotoNoteSnapshot _snapshot({
  required int seed,
  required List<_DetectionSeed> detections,
  String userId = _userId,
  List<_AnnotationSeed> annotations = const [],
}) {
  final noteId = _uuid(seed * 100 + 1);
  final mediaId = _uuid(seed * 100 + 2);
  final scanId = _uuid(seed * 100 + 3);
  final createdAt = DateTime.utc(2026, 9, 2, 2, seed % 60);
  final detectionModels = <VocabDetection>[
    for (var index = 0; index < detections.length; index++)
      VocabDetection(
        id: _uuid(seed * 1000 + index + 1),
        scanRunId: scanId,
        wordRaw: detections[index].word,
        wordNormalized: detections[index].word,
        boundingBox: detections[index].box,
        displayOrder: index,
        createdAt: createdAt,
      ),
  ];
  return PhotoNoteSnapshot(
    photoNote: PhotoNote(
      id: noteId,
      userId: userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Note $seed',
      templateId: 'default-v1',
      createdAt: createdAt,
      updatedAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: userId,
      contentHashSha256: _hash,
      displayRelativePath: 'capy_scans/$seed.jpg',
      mimeType: 'image/jpeg',
      width: 100,
      height: 100,
      orientation: 0,
      byteSizeDisplay: 100,
      preprocessingVersion: 'v1',
      captureSource: CaptureSource.camera,
      capturedAt: createdAt,
      createdAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    primaryScanRun: ScanRun(
      id: scanId,
      userId: userId,
      mediaAssetId: mediaId,
      requestId: 'request-$seed',
      provider: 'test',
      modelName: 'test-model',
      promptVersion: 'v1',
      responseSchemaVersion: 'v1',
      preprocessingVersion: 'v1',
      status: ScanRunStatus.succeeded,
      rawResponseJson: const {'words': []},
      responseHashSha256: _hash,
      startedAt: createdAt,
      completedAt: createdAt,
    ),
    detections: detectionModels,
    annotations: [
      for (var index = 0; index < annotations.length; index++)
        VocabAnnotation(
          id: _uuid(seed * 10000 + index + 1),
          userId: userId,
          detectionId: detectionModels[annotations[index].detectionIndex].id,
          source: annotations[index].correctedWord != null ||
                  annotations[index].correctedBox != null
              ? AnnotationSource.userCorrected
              : AnnotationSource.userConfirmed,
          qualityStatus: annotations[index].quality,
          revision: annotations[index].revision,
          correctedWord: annotations[index].correctedWord,
          correctedBoundingBox: annotations[index].correctedBox,
          createdAt: createdAt,
          updatedAt: createdAt.add(Duration(seconds: index)),
        ),
    ],
  );
}

NormalizedBoundingBox _box(double x) => NormalizedBoundingBox(
      x: x,
      y: 0.1,
      width: 0.1,
      height: 0.1,
    );

String _uuid(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

final class _FakeRepository implements LibraryRepository {
  _FakeRepository(this.snapshots);

  final Map<String, PhotoNoteSnapshot> snapshots;
  final Set<String> requestedUserIds = {};
  final Set<String> requestedPhotoNoteIds = {};

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async {
    requestedUserIds.add(userId);
    requestedPhotoNoteIds.add(photoNoteId);
    return snapshots[photoNoteId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeMediaLoader implements LibraryMediaLoader {
  const _FakeMediaLoader(this.availablePaths);

  final Set<String> availablePaths;

  @override
  Future<Uint8List> readBytes(String relativePath) async => Uint8List(1);

  @override
  Future<int> sizeBytes(String relativePath) async {
    if (!availablePaths.contains(relativePath)) {
      throw const LibraryMediaLoadException('missing');
    }
    return 1;
  }
}
