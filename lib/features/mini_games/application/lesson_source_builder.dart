import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../library/application/library_media_loader.dart';
import '../../library/domain/entities/library_enums.dart';
import '../../library/domain/entities/photo_note_snapshot.dart';
import '../../library/domain/entities/scan_models.dart';
import '../../library/domain/repositories/library_repository.dart';
import '../domain/lesson_game.dart';
import '../domain/lesson_session.dart';

enum LessonSourceExclusionReason {
  ownerMismatch,
  deletedSource,
  missingMedia,
  scanUnavailable,
  rejectedTarget,
  missingBoundingBox,
  invalidAnswer,
  duplicateAnswer,
}

final class LessonSourceBuildResult {
  const LessonSourceBuildResult({
    required this.items,
    required this.sourceRevisionHash,
    required this.exclusionCounts,
  });

  final List<LessonMasteryItem> items;
  final String sourceRevisionHash;
  final Map<LessonSourceExclusionReason, int> exclusionCounts;
}

final class LessonSourceLoader {
  const LessonSourceLoader({
    required LibraryRepository repository,
    required LibraryMediaLoader mediaLoader,
  })  : _repository = repository,
        _mediaLoader = mediaLoader;

  final LibraryRepository _repository;
  final LibraryMediaLoader _mediaLoader;

  Future<LessonSourceBuildResult> load({
    required String userId,
    required Iterable<String> photoNoteIds,
    required int maxItems,
  }) async {
    final uniqueIds = photoNoteIds.toSet().toList()..sort();
    final snapshots = <PhotoNoteSnapshot>[];
    final localPaths = <String>{};
    for (final photoNoteId in uniqueIds) {
      final snapshot = await _repository.getPhotoNoteSnapshot(
        userId: userId,
        photoNoteId: photoNoteId,
      );
      if (snapshot == null) {
        continue;
      }
      snapshots.add(snapshot);
      try {
        if (await _mediaLoader.sizeBytes(
              snapshot.mediaAsset.displayRelativePath,
            ) >
            0) {
          localPaths.add(snapshot.mediaAsset.displayRelativePath);
        }
      } on LibraryMediaLoadException {
        // Missing media is represented in the build result, not as a crash.
      }
    }
    return buildLessonSource(
      userId: userId,
      snapshots: snapshots,
      locallyAvailablePaths: localPaths,
      maxItems: maxItems,
    );
  }

  Future<bool> isSessionSourceAvailable(LessonSession session) async {
    final itemsByPhotoNote = <String, List<LessonMasteryItem>>{};
    for (final item in session.items) {
      itemsByPhotoNote.putIfAbsent(item.photoNoteId, () => []).add(item);
    }
    for (final entry in itemsByPhotoNote.entries) {
      final snapshot = await _repository.getPhotoNoteSnapshot(
        userId: session.userId,
        photoNoteId: entry.key,
      );
      if (snapshot == null ||
          snapshot.photoNote.userId != session.userId ||
          snapshot.photoNote.isDeleted ||
          snapshot.mediaAsset.deletedAt != null ||
          entry.value.any(
            (item) =>
                item.mediaAssetId != snapshot.mediaAsset.id ||
                item.imageRelativePath !=
                    snapshot.mediaAsset.displayRelativePath,
          )) {
        return false;
      }
      try {
        if (await _mediaLoader.sizeBytes(
              snapshot.mediaAsset.displayRelativePath,
            ) <=
            0) {
          return false;
        }
      } on LibraryMediaLoadException {
        return false;
      }
    }
    return true;
  }
}

LessonSourceBuildResult buildLessonSource({
  required String userId,
  required Iterable<PhotoNoteSnapshot> snapshots,
  required Set<String> locallyAvailablePaths,
  required int maxItems,
}) {
  if (maxItems <= 0) {
    throw ArgumentError.value(maxItems, 'maxItems', 'must be positive');
  }
  final orderedSnapshots = snapshots.toList()
    ..sort((left, right) {
      final leftAt = left.mediaAsset.capturedAt ?? left.mediaAsset.createdAt;
      final rightAt = right.mediaAsset.capturedAt ?? right.mediaAsset.createdAt;
      final byTime = leftAt.compareTo(rightAt);
      return byTime != 0
          ? byTime
          : left.photoNote.id.compareTo(right.photoNote.id);
    });
  final exclusionCounts = <LessonSourceExclusionReason, int>{};
  final candidates = <LessonMasteryItem>[];
  final normalizedAnswers = <String>{};

  void exclude(LessonSourceExclusionReason reason, [int count = 1]) {
    exclusionCounts.update(
      reason,
      (current) => current + count,
      ifAbsent: () => count,
    );
  }

  for (final snapshot in orderedSnapshots) {
    if (snapshot.photoNote.userId != userId ||
        snapshot.mediaAsset.userId != userId) {
      exclude(LessonSourceExclusionReason.ownerMismatch);
      continue;
    }
    if (snapshot.photoNote.isDeleted || snapshot.mediaAsset.deletedAt != null) {
      exclude(LessonSourceExclusionReason.deletedSource);
      continue;
    }
    if (!locallyAvailablePaths.contains(
      snapshot.mediaAsset.displayRelativePath,
    )) {
      exclude(LessonSourceExclusionReason.missingMedia);
      continue;
    }
    final scanRun = snapshot.primaryScanRun;
    if (scanRun == null || scanRun.status != ScanRunStatus.succeeded) {
      exclude(LessonSourceExclusionReason.scanUnavailable);
      continue;
    }

    final annotations = snapshot.annotationsByDetectionId;
    final detections = snapshot.detections.toList()
      ..sort((left, right) {
        final byOrder = left.displayOrder.compareTo(right.displayOrder);
        return byOrder != 0 ? byOrder : left.id.compareTo(right.id);
      });
    for (final detection in detections) {
      final latest = _latestActiveAnnotation(
        annotations[detection.id] ?? const [],
      );
      if (latest?.qualityStatus == AnnotationQualityStatus.rejected) {
        exclude(LessonSourceExclusionReason.rejectedTarget);
        continue;
      }
      final sourceBox = latest?.correctedBoundingBox ?? detection.boundingBox;
      if (sourceBox == null) {
        exclude(LessonSourceExclusionReason.missingBoundingBox);
        continue;
      }
      final answer = (latest?.correctedWord ?? detection.wordNormalized).trim();
      final normalizedAnswer = normalizeLessonAnswer(answer);
      if (normalizedAnswer.isEmpty || normalizedAnswer.runes.length > 80) {
        exclude(LessonSourceExclusionReason.invalidAnswer);
        continue;
      }
      if (!normalizedAnswers.add(normalizedAnswer)) {
        exclude(LessonSourceExclusionReason.duplicateAnswer);
        continue;
      }

      final revisionPayload = <Object?>[
        snapshot.photoNote.id,
        snapshot.photoNote.updatedAt.toIso8601String(),
        snapshot.mediaAsset.id,
        snapshot.mediaAsset.contentHashSha256,
        scanRun.id,
        scanRun.responseHashSha256,
        detection.id,
        latest?.id,
        latest?.revision,
        latest?.updatedAt.toIso8601String(),
        normalizedAnswer,
        sourceBox.x,
        sourceBox.y,
        sourceBox.width,
        sourceBox.height,
      ];
      candidates.add(
        LessonMasteryItem(
          id: detection.id,
          photoNoteId: snapshot.photoNote.id,
          mediaAssetId: snapshot.mediaAsset.id,
          imageRelativePath: snapshot.mediaAsset.displayRelativePath,
          imageWidth: snapshot.mediaAsset.width,
          imageHeight: snapshot.mediaAsset.height,
          targetId: detection.id,
          boundingBox: LessonNormalizedBoundingBox(
            x: sourceBox.x,
            y: sourceBox.y,
            width: sourceBox.width,
            height: sourceBox.height,
          ),
          answer: answer,
          sourceRevision: _hashJson(revisionPayload),
        ),
      );
    }
  }

  final selected = List<LessonMasteryItem>.unmodifiable(
    candidates.take(maxItems),
  );
  return LessonSourceBuildResult(
    items: selected,
    sourceRevisionHash: _hashJson([
      for (final item in selected) [item.id, item.sourceRevision],
    ]),
    exclusionCounts: Map.unmodifiable(exclusionCounts),
  );
}

VocabAnnotation? _latestActiveAnnotation(
  Iterable<VocabAnnotation> annotations,
) {
  VocabAnnotation? latest;
  for (final annotation in annotations) {
    if (annotation.deletedAt != null) {
      continue;
    }
    if (latest == null ||
        annotation.revision > latest.revision ||
        (annotation.revision == latest.revision &&
            annotation.updatedAt.isAfter(latest.updatedAt)) ||
        (annotation.revision == latest.revision &&
            annotation.updatedAt == latest.updatedAt &&
            annotation.id.compareTo(latest.id) > 0)) {
      latest = annotation;
    }
  }
  return latest;
}

String _hashJson(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
