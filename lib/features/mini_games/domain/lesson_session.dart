import 'dart:convert';

import 'lesson_game.dart';

enum LessonSessionMode { daily, review }

enum LessonSessionStatus {
  active,
  paused,
  blocked,
  completed,
  abandoned,
  expired,
}

final class LessonSession {
  LessonSession({
    required this.id,
    required this.userId,
    required this.mode,
    required this.status,
    required Iterable<LessonMasteryItem> items,
    required this.mastery,
    required this.sourceRevisionHash,
    required this.ruleVersion,
    required this.normalizerVersion,
    required this.rewardEligible,
    required this.startsAt,
    required this.endsAt,
    required this.nextDayEndsAt,
    required this.startedAt,
    required this.updatedAt,
    this.missionDate,
    this.currentQuestionJson,
    this.draftJson,
    this.completedAt,
    this.abandonedAt,
  }) : items = List.unmodifiable(items) {
    _requireText(id, 'id');
    _requireText(userId, 'userId');
    _requireText(sourceRevisionHash, 'sourceRevisionHash');
    _requireText(ruleVersion, 'ruleVersion');
    _requireText(normalizerVersion, 'normalizerVersion');
    _requireUtc(startsAt, 'startsAt');
    _requireUtc(endsAt, 'endsAt');
    _requireUtc(nextDayEndsAt, 'nextDayEndsAt');
    _requireUtc(startedAt, 'startedAt');
    _requireUtc(updatedAt, 'updatedAt');
    _requireOptionalUtc(completedAt, 'completedAt');
    _requireOptionalUtc(abandonedAt, 'abandonedAt');
    _requireOptionalJson(currentQuestionJson, 'currentQuestionJson');
    _requireOptionalJson(draftJson, 'draftJson');
    if (!startsAt.isBefore(endsAt) || !endsAt.isBefore(nextDayEndsAt)) {
      throw ArgumentError('Lesson session boundaries must be ordered');
    }
    if (this.items.isEmpty) {
      throw ArgumentError('items must not be empty');
    }
    final itemIds = this.items.map((item) => item.id).toSet();
    if (itemIds.length != this.items.length ||
        itemIds.length != mastery.itemIds.length ||
        !itemIds.containsAll(mastery.itemIds)) {
      throw ArgumentError('items must match the mastery snapshot');
    }
    if (mode == LessonSessionMode.daily) {
      _requireUtcDay(missionDate, 'missionDate');
    } else if (missionDate != null) {
      throw ArgumentError('review sessions must not have a missionDate');
    }
    if (mode == LessonSessionMode.review && rewardEligible) {
      throw ArgumentError('review sessions are not reward eligible');
    }
    if (status == LessonSessionStatus.completed) {
      if (!mastery.isComplete || completedAt == null) {
        throw ArgumentError('completed sessions require full mastery and time');
      }
    } else if (completedAt != null) {
      throw ArgumentError('only completed sessions can have completedAt');
    }
    if (status == LessonSessionStatus.abandoned) {
      if (abandonedAt == null || rewardEligible) {
        throw ArgumentError(
          'abandoned sessions require time and cannot earn rewards',
        );
      }
    } else if (abandonedAt != null) {
      throw ArgumentError('only abandoned sessions can have abandonedAt');
    }
    if (status == LessonSessionStatus.expired && rewardEligible) {
      throw ArgumentError('expired sessions cannot earn rewards');
    }
  }

  factory LessonSession.daily({
    required String id,
    required String userId,
    required DateTime missionDate,
    required Iterable<LessonMasteryItem> items,
    required String sourceRevisionHash,
    required String ruleVersion,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime nextDayEndsAt,
    required DateTime startedAt,
  }) {
    final frozenItems = List<LessonMasteryItem>.unmodifiable(items);
    return LessonSession(
      id: id,
      userId: userId,
      missionDate: missionDate,
      mode: LessonSessionMode.daily,
      status: LessonSessionStatus.active,
      items: frozenItems,
      mastery: LessonMasteryState.initial(
        frozenItems.map((item) => item.id),
      ),
      sourceRevisionHash: sourceRevisionHash,
      ruleVersion: ruleVersion,
      normalizerVersion: lessonAnswerNormalizerVersion,
      rewardEligible: true,
      startsAt: startsAt,
      endsAt: endsAt,
      nextDayEndsAt: nextDayEndsAt,
      startedAt: startedAt,
      updatedAt: startedAt,
    );
  }

  factory LessonSession.review({
    required String id,
    required String userId,
    required Iterable<LessonMasteryItem> items,
    required String sourceRevisionHash,
    required String ruleVersion,
    required DateTime startedAt,
  }) {
    final frozenItems = List<LessonMasteryItem>.unmodifiable(items);
    return LessonSession(
      id: id,
      userId: userId,
      mode: LessonSessionMode.review,
      status: LessonSessionStatus.active,
      items: frozenItems,
      mastery: LessonMasteryState.initial(
        frozenItems.map((item) => item.id),
      ),
      sourceRevisionHash: sourceRevisionHash,
      ruleVersion: ruleVersion,
      normalizerVersion: lessonAnswerNormalizerVersion,
      rewardEligible: false,
      startsAt: startedAt,
      endsAt: startedAt.add(const Duration(days: 3650)),
      nextDayEndsAt: startedAt.add(const Duration(days: 3651)),
      startedAt: startedAt,
      updatedAt: startedAt,
    );
  }

  final String id;
  final String userId;
  final DateTime? missionDate;
  final LessonSessionMode mode;
  final LessonSessionStatus status;
  final List<LessonMasteryItem> items;
  final LessonMasteryState mastery;
  final String? currentQuestionJson;
  final String? draftJson;
  final String sourceRevisionHash;
  final String ruleVersion;
  final String normalizerVersion;
  final bool rewardEligible;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime nextDayEndsAt;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? abandonedAt;
}

final class LessonCompletionResult {
  const LessonCompletionResult({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.totalItems,
    required this.completedItems,
    required this.sourceRevisionHash,
    required this.completedAt,
    required this.createdAt,
    required this.syncStatus,
    required this.syncAttemptCount,
    required this.rewardStatus,
    this.nextSyncAttemptAt,
    this.lastSyncErrorCode,
    this.serverAcceptedAt,
    this.rewardYuzu,
    this.weeklyYuzu,
    this.completionOrdinal,
    this.rewardTiming,
    this.rewardedAt,
    this.missionDate,
  });

  final String id;
  final String sessionId;
  final String userId;
  final DateTime? missionDate;
  final int totalItems;
  final int completedItems;
  final String sourceRevisionHash;
  final DateTime completedAt;
  final DateTime createdAt;
  final LessonCompletionSyncStatus syncStatus;
  final int syncAttemptCount;
  final DateTime? nextSyncAttemptAt;
  final String? lastSyncErrorCode;
  final DateTime? serverAcceptedAt;
  final LessonRewardStatus rewardStatus;
  final int? rewardYuzu;
  final int? weeklyYuzu;
  final int? completionOrdinal;
  final LessonRewardTiming? rewardTiming;
  final DateTime? rewardedAt;
}

enum LessonCompletionSyncStatus {
  notApplicable,
  pending,
  syncing,
  synced,
  failed,
}

enum LessonRewardStatus { notApplicable, pending, awarded, rejected }

enum LessonRewardTiming { onTime, late, expired }

final class LessonCompletionSyncPayload {
  LessonCompletionSyncPayload({
    required this.result,
    required this.ruleVersion,
    required this.normalizerVersion,
    required Map<String, Object?> evidence,
  }) : evidence = Map.unmodifiable(evidence) {
    if (result.missionDate == null ||
        result.syncStatus == LessonCompletionSyncStatus.notApplicable) {
      throw ArgumentError('Only daily reward-eligible results can sync');
    }
    _requireText(ruleVersion, 'ruleVersion');
    _requireText(normalizerVersion, 'normalizerVersion');
  }

  final LessonCompletionResult result;
  final String ruleVersion;
  final String normalizerVersion;
  final Map<String, Object?> evidence;
}

final class LessonDayProgress {
  const LessonDayProgress({
    required this.missionDate,
    required this.completedItems,
    required this.totalItems,
    this.completionResultId,
    this.syncStatus,
    this.lastSyncErrorCode,
  });

  final DateTime missionDate;
  final int completedItems;
  final int totalItems;
  final String? completionResultId;
  final LessonCompletionSyncStatus? syncStatus;
  final String? lastSyncErrorCode;

  bool get isCompleted => completedItems == totalItems;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'must be UTC');
  }
}

void _requireOptionalUtc(DateTime? value, String name) {
  if (value != null) {
    _requireUtc(value, name);
  }
}

void _requireUtcDay(DateTime? value, String name) {
  if (value == null ||
      !value.isUtc ||
      value != DateTime.utc(value.year, value.month, value.day)) {
    throw ArgumentError.value(value, name, 'must be a UTC calendar date');
  }
}

void _requireOptionalJson(String? value, String name) {
  if (value == null) {
    return;
  }
  try {
    jsonDecode(value);
  } on FormatException {
    throw ArgumentError.value(value, name, 'must be valid JSON');
  }
}
