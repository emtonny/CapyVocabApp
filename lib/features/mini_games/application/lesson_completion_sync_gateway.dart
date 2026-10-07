import '../domain/lesson_session.dart';

enum LessonSyncFailureDisposition { retry, blocked }

final class LessonSyncFailure implements Exception {
  const LessonSyncFailure.retry(this.code)
      : disposition = LessonSyncFailureDisposition.retry;

  const LessonSyncFailure.blocked(this.code)
      : disposition = LessonSyncFailureDisposition.blocked;

  final String code;
  final LessonSyncFailureDisposition disposition;

  @override
  String toString() => 'LessonSyncFailure($code, $disposition)';
}

final class LessonCompletionReceipt {
  const LessonCompletionReceipt({
    required this.resultId,
    required this.userId,
    required this.acceptedAt,
    required this.rewardStatus,
    required this.weeklyYuzu,
    required this.completionOrdinal,
    required this.rewardTiming,
    this.rewardYuzu,
    this.rewardedAt,
  });

  final String resultId;
  final String userId;
  final DateTime acceptedAt;
  final LessonRewardStatus rewardStatus;
  final int? rewardYuzu;
  final int weeklyYuzu;
  final int completionOrdinal;
  final LessonRewardTiming rewardTiming;
  final DateTime? rewardedAt;
}

abstract interface class LessonCompletionSyncGateway {
  String? get authenticatedUserId;

  Future<LessonCompletionReceipt> sync(LessonCompletionSyncPayload payload);
}
