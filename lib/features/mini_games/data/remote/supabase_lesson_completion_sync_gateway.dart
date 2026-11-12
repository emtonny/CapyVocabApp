import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/lesson_completion_sync_gateway.dart';
import '../../domain/lesson_session.dart';

final class SupabaseLessonCompletionSyncGateway
    implements LessonCompletionSyncGateway {
  const SupabaseLessonCompletionSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  String? get authenticatedUserId => _client.auth.currentUser?.id;

  @override
  Future<LessonCompletionReceipt> sync(
    LessonCompletionSyncPayload payload,
  ) async {
    final result = payload.result;
    final missionDate = result.missionDate;
    if (missionDate == null || authenticatedUserId != result.userId) {
      throw const LessonSyncFailure.blocked('auth_required');
    }
    try {
      final response = await _client.rpc(
        'sync_lesson_completion',
        params: {
          'p_result_id': result.id,
          'p_session_id': result.sessionId,
          'p_mission_date': _encodeDay(missionDate),
          'p_total_items': result.totalItems,
          'p_completed_items': result.completedItems,
          'p_source_revision_hash': result.sourceRevisionHash,
          'p_rule_version': payload.ruleVersion,
          'p_normalizer_version': payload.normalizerVersion,
          'p_evidence': payload.evidence,
          'p_completed_at': result.completedAt.toIso8601String(),
        },
      );
      return decodeLessonCompletionReceipt(response);
    } on PostgrestException catch (error) {
      if ({'22023', '23505', 'P0002', '42501'}.contains(error.code)) {
        throw LessonSyncFailure.blocked(
          error.code == '23505' ? 'payload_conflict' : 'contract_rejected',
        );
      }
      throw LessonSyncFailure.retry(error.code ?? 'postgrest_error');
    } on AuthException {
      throw const LessonSyncFailure.retry('auth_refresh_required');
    }
  }
}

LessonCompletionReceipt decodeLessonCompletionReceipt(Object? response) {
  final Object? value = switch (response) {
    Map() => response,
    List(length: 1) => response.single,
    _ => null,
  };
  if (value is! Map) {
    throw const LessonSyncFailure.blocked('invalid_server_receipt');
  }
  final row = Map<String, Object?>.from(value);
  final resultId = row['result_id'];
  final userId = row['user_id'];
  final acceptedAt = DateTime.tryParse('${row['accepted_at'] ?? ''}');
  final rewardStatus = _decodeRewardStatus(row['reward_status']);
  final rewardYuzu = _optionalNonNegativeInt(row['reward_yuzu']);
  final weeklyYuzu = _nonNegativeInt(row['weekly_yuzu']);
  final completionOrdinal = _positiveInt(row['completion_ordinal']);
  final rewardTiming = _decodeRewardTiming(row['reward_timing']);
  final rewardedAt = row['rewarded_at'] == null
      ? null
      : DateTime.tryParse('${row['rewarded_at']}');
  if (resultId is! String ||
      resultId.isEmpty ||
      userId is! String ||
      userId.isEmpty ||
      acceptedAt == null ||
      rewardStatus == null ||
      weeklyYuzu == null ||
      completionOrdinal == null ||
      rewardTiming == null ||
      (row['rewarded_at'] != null && rewardedAt == null) ||
      (rewardStatus == LessonRewardStatus.awarded &&
          (rewardYuzu == null || rewardedAt == null)) ||
      (rewardStatus == LessonRewardStatus.rejected && rewardYuzu != null)) {
    throw const LessonSyncFailure.blocked('invalid_server_receipt');
  }
  return LessonCompletionReceipt(
    resultId: resultId,
    userId: userId,
    acceptedAt: acceptedAt.toUtc(),
    rewardStatus: rewardStatus,
    rewardYuzu: rewardYuzu,
    weeklyYuzu: weeklyYuzu,
    completionOrdinal: completionOrdinal,
    rewardTiming: rewardTiming,
    rewardedAt: rewardedAt?.toUtc(),
  );
}

LessonRewardStatus? _decodeRewardStatus(Object? value) => switch (value) {
      'awarded' => LessonRewardStatus.awarded,
      'rejected' => LessonRewardStatus.rejected,
      _ => null,
    };

LessonRewardTiming? _decodeRewardTiming(Object? value) => switch (value) {
      'on_time' => LessonRewardTiming.onTime,
      'late' => LessonRewardTiming.late,
      'expired' => LessonRewardTiming.expired,
      _ => null,
    };

int? _optionalNonNegativeInt(Object? value) =>
    value == null ? null : _nonNegativeInt(value);

int? _nonNegativeInt(Object? value) {
  if (value is num && value == value.toInt() && value >= 0) {
    return value.toInt();
  }
  return null;
}

int? _positiveInt(Object? value) {
  final result = _nonNegativeInt(value);
  return result != null && result > 0 ? result : null;
}

String _encodeDay(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
