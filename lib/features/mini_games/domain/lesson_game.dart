import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

const lessonAnswerNormalizerVersion = 'nfc-trim-lower-v1';

enum LessonGameType { photoOrderQuiz, photoLetterFill }

enum LessonStage { intro, playing, feedback, completed }

extension LessonStageAdPolicy on LessonStage {
  bool get allowsAds =>
      this == LessonStage.intro || this == LessonStage.completed;
}

String normalizeLessonAnswer(String value) =>
    unorm.nfc(value.trim()).toLowerCase();

final class LessonNormalizedBoundingBox {
  LessonNormalizedBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) {
    if (!x.isFinite ||
        !y.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      throw ArgumentError('bounding box must fit inside the unit rectangle');
    }
  }

  final double x;
  final double y;
  final double width;
  final double height;
}

final class LessonMasteryItem {
  LessonMasteryItem({
    required this.id,
    required this.photoNoteId,
    required this.mediaAssetId,
    required this.imageRelativePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.targetId,
    required this.boundingBox,
    required this.answer,
    required this.sourceRevision,
  }) : answerNormalized = normalizeLessonAnswer(answer) {
    _requireText(id, 'id');
    _requireText(photoNoteId, 'photoNoteId');
    _requireText(mediaAssetId, 'mediaAssetId');
    _requireText(imageRelativePath, 'imageRelativePath');
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('image dimensions must be positive');
    }
    _requireText(targetId, 'targetId');
    _requireText(sourceRevision, 'sourceRevision');
    if (answerNormalized.isEmpty) {
      throw ArgumentError.value(answer, 'answer', 'must not be blank');
    }
  }

  final String id;
  final String photoNoteId;
  final String mediaAssetId;
  final String imageRelativePath;
  final int imageWidth;
  final int imageHeight;
  final String targetId;
  final LessonNormalizedBoundingBox boundingBox;
  final String answer;
  final String answerNormalized;
  final String sourceRevision;
}

final class PhotoOrderTarget {
  PhotoOrderTarget({required this.marker, required this.itemId}) {
    if (marker < 1) {
      throw ArgumentError.value(marker, 'marker', 'must be positive');
    }
    _requireText(itemId, 'itemId');
  }

  final int marker;
  final String itemId;
}

final class PhotoOrderQuestion {
  PhotoOrderQuestion({
    required this.id,
    required Iterable<PhotoOrderTarget> targets,
  }) : targets = List.unmodifiable(targets) {
    _requireText(id, 'id');
    if (this.targets.length < 2 || this.targets.length > 4) {
      throw ArgumentError.value(
        this.targets.length,
        'targets',
        'must contain 2 to 4 targets',
      );
    }
    final markers = this.targets.map((target) => target.marker).toSet();
    final itemIds = this.targets.map((target) => target.itemId).toSet();
    if (markers.length != this.targets.length ||
        itemIds.length != this.targets.length) {
      throw ArgumentError('targets must have unique markers and item IDs');
    }
    for (var index = 0; index < this.targets.length; index++) {
      if (!markers.contains(index + 1)) {
        throw ArgumentError('target markers must be contiguous from 1');
      }
    }
  }

  final String id;
  final List<PhotoOrderTarget> targets;
}

final class PhotoOrderSubmission {
  PhotoOrderSubmission({
    required this.attemptId,
    required this.questionId,
    required Map<int, String> itemIdByMarker,
  }) : itemIdByMarker = Map.unmodifiable(itemIdByMarker) {
    _requireText(attemptId, 'attemptId');
    _requireText(questionId, 'questionId');
  }

  final String attemptId;
  final String questionId;
  final Map<int, String> itemIdByMarker;
}

final class PhotoLetterFillQuestion {
  PhotoLetterFillQuestion({
    required this.id,
    required this.itemId,
    required this.expectedAnswer,
  }) : expectedAnswerNormalized = normalizeLessonAnswer(expectedAnswer) {
    _requireText(id, 'id');
    _requireText(itemId, 'itemId');
    if (expectedAnswerNormalized.isEmpty) {
      throw ArgumentError.value(
        expectedAnswer,
        'expectedAnswer',
        'must not be blank',
      );
    }
  }

  final String id;
  final String itemId;
  final String expectedAnswer;
  final String expectedAnswerNormalized;
}

final class PhotoLetterFillSubmission {
  PhotoLetterFillSubmission({
    required this.attemptId,
    required this.questionId,
    required this.answer,
  }) {
    _requireText(attemptId, 'attemptId');
    _requireText(questionId, 'questionId');
  }

  final String attemptId;
  final String questionId;
  final String answer;
}

final class LessonItemVerdict {
  const LessonItemVerdict({required this.itemId, required this.isCorrect});

  final String itemId;
  final bool isCorrect;
}

final class LessonGradedAttempt {
  LessonGradedAttempt({
    required this.attemptId,
    required this.questionId,
    required this.gameType,
    required this.payloadFingerprint,
    required Iterable<LessonItemVerdict> verdicts,
  }) : verdicts = List.unmodifiable(verdicts) {
    _requireText(attemptId, 'attemptId');
    _requireText(questionId, 'questionId');
    _requireText(payloadFingerprint, 'payloadFingerprint');
    if (this.verdicts.isEmpty) {
      throw ArgumentError('verdicts must not be empty');
    }
    final itemIds = this.verdicts.map((verdict) => verdict.itemId).toSet();
    if (itemIds.length != this.verdicts.length || itemIds.contains('')) {
      throw ArgumentError('verdicts must have unique non-empty item IDs');
    }
  }

  final String attemptId;
  final String questionId;
  final LessonGameType gameType;
  final String payloadFingerprint;
  final List<LessonItemVerdict> verdicts;
}

LessonGradedAttempt gradePhotoOrder(
  PhotoOrderQuestion question,
  PhotoOrderSubmission submission,
) {
  if (submission.questionId != question.id) {
    throw ArgumentError('submission belongs to another question');
  }
  final expectedMarkers =
      question.targets.map((target) => target.marker).toSet();
  final expectedItems = question.targets.map((target) => target.itemId).toSet();
  if (!_sameSet(submission.itemIdByMarker.keys.toSet(), expectedMarkers) ||
      !_sameSet(submission.itemIdByMarker.values.toSet(), expectedItems) ||
      submission.itemIdByMarker.length != question.targets.length) {
    throw ArgumentError(
      'order submission must be a full permutation of the question cards',
    );
  }

  final canonicalByMarker = <int, String>{
    for (final target in question.targets) target.marker: target.itemId,
  };
  final markers = expectedMarkers.toList()..sort();
  return LessonGradedAttempt(
    attemptId: submission.attemptId,
    questionId: question.id,
    gameType: LessonGameType.photoOrderQuiz,
    payloadFingerprint: jsonEncode([
      question.id,
      for (final marker in markers) [marker, submission.itemIdByMarker[marker]],
    ]),
    verdicts: [
      for (final marker in markers)
        LessonItemVerdict(
          itemId: canonicalByMarker[marker]!,
          isCorrect:
              canonicalByMarker[marker] == submission.itemIdByMarker[marker],
        ),
    ],
  );
}

LessonGradedAttempt gradePhotoLetterFill(
  PhotoLetterFillQuestion question,
  PhotoLetterFillSubmission submission,
) {
  if (submission.questionId != question.id) {
    throw ArgumentError('submission belongs to another question');
  }
  final normalizedAnswer = normalizeLessonAnswer(submission.answer);
  if (normalizedAnswer.isEmpty) {
    throw ArgumentError.value(submission.answer, 'answer', 'must not be blank');
  }
  if (normalizedAnswer.runes.length > 80) {
    throw ArgumentError.value(submission.answer, 'answer', 'is too long');
  }
  return LessonGradedAttempt(
    attemptId: submission.attemptId,
    questionId: question.id,
    gameType: LessonGameType.photoLetterFill,
    payloadFingerprint: jsonEncode([
      question.id,
      lessonAnswerNormalizerVersion,
      normalizedAnswer,
    ]),
    verdicts: [
      LessonItemVerdict(
        itemId: question.itemId,
        isCorrect: normalizedAnswer == question.expectedAnswerNormalized,
      ),
    ],
  );
}

final class LessonMasteryState {
  LessonMasteryState({
    required Iterable<String> itemIds,
    required Iterable<String> pendingQueue,
    required Iterable<String> masteredItemIds,
    Map<String, LessonGradedAttempt> attempts = const {},
  })  : itemIds = Set.unmodifiable(itemIds),
        pendingQueue = List.unmodifiable(pendingQueue),
        masteredItemIds = Set.unmodifiable(masteredItemIds),
        attempts = Map.unmodifiable(attempts) {
    if (this.itemIds.isEmpty || this.itemIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('itemIds must contain non-empty IDs');
    }
    if (this.pendingQueue.toSet().length != this.pendingQueue.length) {
      throw ArgumentError('pendingQueue must not contain duplicate IDs');
    }
    if (!this.itemIds.containsAll(this.pendingQueue) ||
        !this.itemIds.containsAll(this.masteredItemIds)) {
      throw ArgumentError('queue and mastery must reference known items');
    }
    if (this.pendingQueue.any(masteredItemIds.contains)) {
      throw ArgumentError('an item cannot be pending and mastered');
    }
    if ({...this.pendingQueue, ...this.masteredItemIds}.length !=
        this.itemIds.length) {
      throw ArgumentError('every item must be pending or mastered');
    }
    for (final entry in this.attempts.entries) {
      if (entry.key != entry.value.attemptId) {
        throw ArgumentError('attempt map key must match attemptId');
      }
    }
  }

  factory LessonMasteryState.initial(Iterable<String> itemIds) {
    final frozen = List<String>.unmodifiable(itemIds);
    if (frozen.toSet().length != frozen.length) {
      throw ArgumentError('itemIds must be unique');
    }
    return LessonMasteryState(
      itemIds: frozen,
      pendingQueue: frozen,
      masteredItemIds: const {},
    );
  }

  final Set<String> itemIds;
  final List<String> pendingQueue;
  final Set<String> masteredItemIds;
  final Map<String, LessonGradedAttempt> attempts;

  int get totalCount => itemIds.length;
  int get completedCount => masteredItemIds.length;
  bool get isComplete => pendingQueue.isEmpty;
}

final class LessonApplyResult {
  const LessonApplyResult({
    required this.state,
    required this.attempt,
    required this.isReplay,
  });

  final LessonMasteryState state;
  final LessonGradedAttempt attempt;
  final bool isReplay;
}

final class LessonAttemptConflict implements Exception {
  const LessonAttemptConflict(this.attemptId);

  final String attemptId;

  @override
  String toString() => 'LessonAttemptConflict: $attemptId';
}

LessonApplyResult applyLessonAttempt(
  LessonMasteryState state,
  LessonGradedAttempt attempt,
) {
  final existing = state.attempts[attempt.attemptId];
  if (existing != null) {
    if (!_sameAttempt(existing, attempt)) {
      throw LessonAttemptConflict(attempt.attemptId);
    }
    return LessonApplyResult(
      state: state,
      attempt: existing,
      isReplay: true,
    );
  }

  final verdictItemIds =
      attempt.verdicts.map((verdict) => verdict.itemId).toSet();
  if (!state.pendingQueue.toSet().containsAll(verdictItemIds)) {
    throw StateError('attempt references an item that is no longer pending');
  }

  final nextQueue = state.pendingQueue
      .where((itemId) => !verdictItemIds.contains(itemId))
      .toList();
  final nextMastered = state.masteredItemIds.toSet();
  for (final verdict in attempt.verdicts) {
    if (verdict.isCorrect) {
      nextMastered.add(verdict.itemId);
    } else {
      nextQueue.add(verdict.itemId);
    }
  }
  final nextAttempts = {...state.attempts, attempt.attemptId: attempt};
  final nextState = LessonMasteryState(
    itemIds: state.itemIds,
    pendingQueue: nextQueue,
    masteredItemIds: nextMastered,
    attempts: nextAttempts,
  );
  return LessonApplyResult(
    state: nextState,
    attempt: attempt,
    isReplay: false,
  );
}

bool _sameAttempt(LessonGradedAttempt left, LessonGradedAttempt right) {
  if (left.attemptId != right.attemptId ||
      left.questionId != right.questionId ||
      left.gameType != right.gameType ||
      left.payloadFingerprint != right.payloadFingerprint ||
      left.verdicts.length != right.verdicts.length) {
    return false;
  }
  for (var index = 0; index < left.verdicts.length; index++) {
    final leftVerdict = left.verdicts[index];
    final rightVerdict = right.verdicts[index];
    if (leftVerdict.itemId != rightVerdict.itemId ||
        leftVerdict.isCorrect != rightVerdict.isCorrect) {
      return false;
    }
  }
  return true;
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}
