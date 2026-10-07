import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../application/lesson_completion_sync_store.dart';
import '../../application/lesson_completion_sync_gateway.dart';
import '../../domain/lesson_game.dart';
import '../../domain/lesson_session.dart';

final class PersistedLessonAttemptResult {
  const PersistedLessonAttemptResult({
    required this.session,
    required this.application,
    required this.completion,
  });

  final LessonSession session;
  final LessonApplyResult application;
  final LessonCompletionResult? completion;
}

final class SqliteLessonSessionStore implements LessonCompletionSyncStore {
  SqliteLessonSessionStore(this._database);

  final Database _database;
  final StreamController<String> _changes = StreamController.broadcast();

  @override
  Stream<void> watchChanges(String userId) async* {
    yield null;
    yield* _changes.stream.where((changedUserId) => changedUserId == userId);
  }

  Future<void> create(LessonSession session) async {
    await _database.insert('lesson_sessions', _sessionToMap(session));
    _changes.add(session.userId);
  }

  Future<LessonSession> createOrLoadDaily(LessonSession session) async {
    if (session.mode != LessonSessionMode.daily ||
        session.missionDate == null) {
      throw ArgumentError('createOrLoadDaily requires a daily session');
    }
    final persisted = await _database.transaction((transaction) async {
      await transaction.insert(
        'lesson_sessions',
        _sessionToMap(session),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final rows = await transaction.query(
        'lesson_sessions',
        where: 'user_id = ? AND mission_date = ? AND mode = ?',
        whereArgs: [
          session.userId,
          _encodeDay(session.missionDate!),
          'daily',
        ],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Daily lesson session was not persisted.');
      }
      return _decodeSession(transaction, rows.single);
    });
    _changes.add(session.userId);
    return persisted;
  }

  Future<LessonSession> createOrLoadRewardedReplay({
    required LessonSession session,
    required DateTime missionDate,
  }) async {
    _requireUtc(missionDate, 'missionDate');
    if (session.mode != LessonSessionMode.review || session.rewardEligible) {
      throw ArgumentError('Rewarded replay uses a local review snapshot');
    }
    final persisted = await _database.transaction((transaction) async {
      await transaction.insert(
        'lesson_sessions',
        _sessionToMap(session),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await transaction.insert(
        'rewarded_replay_sessions',
        {
          'session_id': session.id,
          'user_id': session.userId,
          'mission_date': _encodeDay(missionDate),
          'created_at': session.startedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final rows = await transaction.rawQuery('''
        SELECT session.*
        FROM rewarded_replay_sessions AS replay
        JOIN lesson_sessions AS session
          ON session.id = replay.session_id
         AND session.user_id = replay.user_id
        WHERE replay.user_id = ? AND replay.mission_date = ?
        LIMIT 1
      ''', [session.userId, _encodeDay(missionDate)]);
      if (rows.isEmpty) {
        throw StateError('Rewarded replay session was not persisted.');
      }
      return _decodeSession(transaction, rows.single);
    });
    _changes.add(session.userId);
    return persisted;
  }

  Future<LessonSession?> getRewardedReplay({
    required String userId,
    required DateTime missionDate,
  }) async {
    final rows = await _database.rawQuery('''
      SELECT session.*
      FROM rewarded_replay_sessions AS replay
      JOIN lesson_sessions AS session
        ON session.id = replay.session_id
       AND session.user_id = replay.user_id
      WHERE replay.user_id = ? AND replay.mission_date = ?
      LIMIT 1
    ''', [userId, _encodeDay(missionDate)]);
    if (rows.isEmpty) return null;
    return _database.transaction(
      (transaction) => _decodeSession(transaction, rows.single),
    );
  }

  Future<LessonSession?> get({
    required String userId,
    required String sessionId,
  }) {
    return _database.transaction(
      (transaction) => _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ),
    );
  }

  Future<LessonSession?> getDaily({
    required String userId,
    required DateTime missionDate,
  }) async {
    final rows = await _database.query(
      'lesson_sessions',
      where: 'user_id = ? AND mission_date = ? AND mode = ?',
      whereArgs: [userId, _encodeDay(missionDate), 'daily'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _database.transaction(
      (transaction) => _decodeSession(transaction, rows.single),
    );
  }

  Future<void> saveDraft({
    required String userId,
    required String sessionId,
    required String? currentQuestionJson,
    required String? draftJson,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    _validateOptionalJson(currentQuestionJson, 'currentQuestionJson');
    _validateOptionalJson(draftJson, 'draftJson');
    final changed = await _database.update(
      'lesson_sessions',
      {
        'current_question_json': currentQuestionJson,
        'draft_json': draftJson,
        'updated_at': now.toIso8601String(),
      },
      where: "id = ? AND user_id = ? AND status = 'active'",
      whereArgs: [sessionId, userId],
    );
    if (changed != 1) {
      throw StateError('Active lesson session not found.');
    }
  }

  Future<LessonSession> pause({
    required String userId,
    required String sessionId,
    required String? currentQuestionJson,
    required String? draftJson,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    _validateOptionalJson(currentQuestionJson, 'currentQuestionJson');
    _validateOptionalJson(draftJson, 'draftJson');
    final persisted = await _database.transaction((transaction) async {
      final changed = await transaction.update(
        'lesson_sessions',
        {
          'status': 'paused',
          'current_question_json': currentQuestionJson,
          'draft_json': draftJson,
          'updated_at': now.toIso8601String(),
        },
        where: "id = ? AND user_id = ? AND status = 'active'",
        whereArgs: [sessionId, userId],
      );
      if (changed != 1) {
        throw StateError('Active lesson session not found.');
      }
      return (await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ))!;
    });
    _changes.add(userId);
    return persisted;
  }

  Future<LessonSession> resume({
    required String userId,
    required String sessionId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    final persisted = await _database.transaction((transaction) async {
      final changed = await transaction.update(
        'lesson_sessions',
        {'status': 'active', 'updated_at': now.toIso8601String()},
        where: "id = ? AND user_id = ? AND status = 'paused'",
        whereArgs: [sessionId, userId],
      );
      if (changed != 1) {
        throw StateError('Paused lesson session not found.');
      }
      return (await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ))!;
    });
    _changes.add(userId);
    return persisted;
  }

  Future<LessonSession> abandon({
    required String userId,
    required String sessionId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    final persisted = await _database.transaction((transaction) async {
      final changed = await transaction.update(
        'lesson_sessions',
        {
          'status': 'abandoned',
          'reward_eligible': 0,
          'abandoned_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: "id = ? AND user_id = ? AND status IN ('active', 'paused')",
        whereArgs: [sessionId, userId],
      );
      if (changed != 1) {
        throw StateError('Abandonable lesson session not found.');
      }
      return (await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ))!;
    });
    _changes.add(userId);
    return persisted;
  }

  Future<LessonSession> block({
    required String userId,
    required String sessionId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    return _database.transaction((transaction) async {
      final changed = await transaction.update(
        'lesson_sessions',
        {'status': 'blocked', 'updated_at': now.toIso8601String()},
        where: "id = ? AND user_id = ? AND status IN ('active', 'paused')",
        whereArgs: [sessionId, userId],
      );
      if (changed != 1) {
        throw StateError('Blockable lesson session not found.');
      }
      return (await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ))!;
    });
  }

  Future<LessonSession> expire({
    required String userId,
    required String sessionId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    return _database.transaction((transaction) async {
      final changed = await transaction.update(
        'lesson_sessions',
        {
          'status': 'expired',
          'reward_eligible': 0,
          'updated_at': now.toIso8601String(),
        },
        where:
            "id = ? AND user_id = ? AND status IN ('active', 'paused', 'blocked')",
        whereArgs: [sessionId, userId],
      );
      if (changed != 1) {
        throw StateError('Expirable lesson session not found.');
      }
      return (await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      ))!;
    });
  }

  Future<PersistedLessonAttemptResult> applyAttempt({
    required String userId,
    required String sessionId,
    required LessonGradedAttempt attempt,
    required DateTime now,
    String? nextQuestionJson,
    String? nextDraftJson,
  }) async {
    _requireUtc(now, 'now');
    _validateOptionalJson(nextQuestionJson, 'nextQuestionJson');
    _validateOptionalJson(nextDraftJson, 'nextDraftJson');
    final persisted = await _database.transaction((transaction) async {
      final session = await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      );
      if (session == null) {
        throw StateError('Lesson session not found.');
      }

      final application = applyLessonAttempt(session.mastery, attempt);
      if (application.isReplay) {
        return PersistedLessonAttemptResult(
          session: session,
          application: application,
          completion: await _getCompletion(
            transaction,
            userId: userId,
            sessionId: sessionId,
          ),
        );
      }
      if (session.status != LessonSessionStatus.active) {
        throw StateError('Only an active lesson session accepts attempts.');
      }

      await transaction.insert(
        'lesson_attempts',
        _attemptToMap(
          userId: userId,
          sessionId: sessionId,
          attempt: attempt,
          occurredAt: now,
        ),
      );

      final nextState = application.state;
      final replayRows = await transaction.query(
        'rewarded_replay_sessions',
        columns: ['mission_date'],
        where: 'session_id = ? AND user_id = ?',
        whereArgs: [sessionId, userId],
        limit: 1,
      );
      final replayMissionDate = replayRows.isEmpty
          ? null
          : _decodeDay(replayRows.single['mission_date']! as String);
      final completedAt = nextState.isComplete ? now : null;
      final nextStatus = nextState.isComplete ? 'completed' : 'active';
      await transaction.update(
        'lesson_sessions',
        {
          'status': nextStatus,
          'completed_items': nextState.completedCount,
          'pending_queue_json': jsonEncode(nextState.pendingQueue),
          'mastered_item_ids_json': jsonEncode(
            nextState.masteredItemIds.toList()..sort(),
          ),
          'current_question_json':
              nextState.isComplete ? null : nextQuestionJson,
          'draft_json': nextState.isComplete ? null : nextDraftJson,
          'updated_at': now.toIso8601String(),
          'completed_at': completedAt?.toIso8601String(),
        },
        where: "id = ? AND user_id = ? AND status = 'active'",
        whereArgs: [sessionId, userId],
      );

      LessonCompletionResult? completion;
      if (nextState.isComplete) {
        final resultMap = {
          'id': '$sessionId:completion',
          'session_id': sessionId,
          'user_id': userId,
          'mission_date': replayMissionDate == null
              ? (session.missionDate == null
                  ? null
                  : _encodeDay(session.missionDate!))
              : _encodeDay(replayMissionDate),
          'total_items': nextState.totalCount,
          'completed_items': nextState.completedCount,
          'source_revision_hash': session.sourceRevisionHash,
          'completed_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'sync_status': replayMissionDate != null ||
                  (session.mode == LessonSessionMode.daily &&
                      session.rewardEligible)
              ? 'pending'
              : 'not_applicable',
          'sync_attempt_count': 0,
          'next_sync_attempt_at': null,
          'last_sync_error_code': null,
          'sync_updated_at': now.toIso8601String(),
          'server_accepted_at': null,
          'reward_status': replayMissionDate != null || session.rewardEligible
              ? 'pending'
              : 'not_applicable',
          'reward_yuzu': null,
          'weekly_yuzu': null,
          'completion_ordinal': null,
          'reward_timing': null,
          'rewarded_at': null,
        };
        await transaction.insert('lesson_completion_results', resultMap);
        completion = _completionFromMap(resultMap);
      }

      final updated = await _getSession(
        transaction,
        userId: userId,
        sessionId: sessionId,
      );
      return PersistedLessonAttemptResult(
        session: updated!,
        application: application,
        completion: completion,
      );
    });
    _changes.add(userId);
    return persisted;
  }

  Future<LessonCompletionResult?> getCompletion({
    required String userId,
    required String sessionId,
  }) {
    return _getCompletion(
      _database,
      userId: userId,
      sessionId: sessionId,
    );
  }

  Future<List<LessonDayProgress>> listDailyProgress({
    required String userId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    _requireUtc(fromInclusive, 'fromInclusive');
    _requireUtc(toExclusive, 'toExclusive');
    if (!fromInclusive.isBefore(toExclusive)) {
      throw ArgumentError('Daily progress range must be ordered');
    }
    final rows = await _database.rawQuery('''
      SELECT
        session.mission_date,
        session.completed_items,
        session.total_items,
        result.id AS completion_result_id,
        result.sync_status,
        result.last_sync_error_code
      FROM lesson_sessions AS session
      LEFT JOIN lesson_completion_results AS result
        ON result.session_id = session.id
       AND result.user_id = session.user_id
      WHERE session.user_id = ?
        AND session.mode = 'daily'
        AND session.mission_date >= ?
        AND session.mission_date < ?
      ORDER BY session.mission_date ASC
    ''', [
      userId,
      _encodeDay(fromInclusive),
      _encodeDay(toExclusive),
    ]);
    return List.unmodifiable([
      for (final row in rows)
        LessonDayProgress(
          missionDate: _decodeDay(row['mission_date']! as String)!,
          completedItems: row['completed_items']! as int,
          totalItems: row['total_items']! as int,
          completionResultId: row['completion_result_id'] as String?,
          syncStatus: row['sync_status'] == null
              ? null
              : _decodeSyncStatus(row['sync_status']! as String),
          lastSyncErrorCode: row['last_sync_error_code'] as String?,
        ),
    ]);
  }

  Future<int> pendingYuzuEstimate(String userId) async {
    final rows = await _database.rawQuery('''
      SELECT
        result.total_items,
        mission.target_words,
        replay.session_id IS NOT NULL AS is_replay
      FROM lesson_completion_results AS result
      JOIN lesson_sessions AS session
        ON session.id = result.session_id
       AND session.user_id = result.user_id
      JOIN daily_missions AS mission
        ON mission.user_id = result.user_id
       AND mission.mission_date = result.mission_date
      LEFT JOIN rewarded_replay_sessions AS replay
        ON replay.session_id = result.session_id
       AND replay.user_id = result.user_id
      WHERE result.user_id = ?
        AND result.mission_date IS NOT NULL
        AND result.reward_status = 'pending'
    ''', [userId]);
    return rows.fold<int>(0, (total, row) {
      final projected = _projectedYuzu(
        row['total_items']! as int,
        row['target_words']! as int,
      );
      return total + (row['is_replay'] == 1 ? projected ~/ 3 : projected);
    });
  }

  @override
  Future<int> outstandingSyncCount(String userId) async {
    final rows = await _database.rawQuery('''
      SELECT COUNT(*) AS count
      FROM lesson_completion_results
      WHERE user_id = ? AND sync_status IN ('pending', 'syncing', 'failed')
    ''', [userId]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<DateTime?> nextSyncAttemptAt(String userId) async {
    final rows = await _database.rawQuery('''
      SELECT MIN(next_sync_attempt_at) AS next_at
      FROM lesson_completion_results
      WHERE user_id = ?
        AND sync_status = 'failed'
        AND next_sync_attempt_at IS NOT NULL
    ''', [userId]);
    final value = rows.single['next_at'] as String?;
    return value == null ? null : _decodeUtc(value);
  }

  @override
  Future<List<LessonCompletionSyncPayload>> readySyncPayloads({
    required String userId,
    required DateTime now,
    int limit = 20,
  }) async {
    _requireUtc(now, 'now');
    if (limit <= 0 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    final rows = await _database.query(
      'lesson_completion_results',
      columns: ['id'],
      where: '''
        user_id = ?
        AND mission_date IS NOT NULL
        AND (
          sync_status = 'pending'
          OR (sync_status = 'failed' AND next_sync_attempt_at IS NOT NULL
              AND next_sync_attempt_at <= ?)
        )
      ''',
      whereArgs: [userId, now.toIso8601String()],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    final payloads = <LessonCompletionSyncPayload>[];
    for (final row in rows) {
      final payload = await _syncPayload(
        userId: userId,
        resultId: row['id']! as String,
      );
      if (payload != null) payloads.add(payload);
    }
    return List.unmodifiable(payloads);
  }

  @override
  Future<LessonCompletionResult?> markSyncing({
    required String userId,
    required String resultId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    final changed = await _database.rawUpdate('''
      UPDATE lesson_completion_results
      SET
        sync_status = 'syncing',
        sync_attempt_count = sync_attempt_count + 1,
        next_sync_attempt_at = NULL,
        last_sync_error_code = NULL,
        sync_updated_at = ?
      WHERE id = ? AND user_id = ?
        AND sync_status IN ('pending', 'failed')
    ''', [now.toIso8601String(), resultId, userId]);
    if (changed != 1) return null;
    _changes.add(userId);
    return _getCompletionById(_database, userId: userId, resultId: resultId);
  }

  @override
  Future<void> markSynced({
    required String userId,
    required String resultId,
    required LessonCompletionReceipt receipt,
    required DateTime now,
  }) async {
    if (receipt.resultId != resultId || receipt.userId != userId) {
      throw ArgumentError('Receipt identity does not match the local result');
    }
    _requireUtc(receipt.acceptedAt, 'acceptedAt');
    if (receipt.rewardedAt != null) {
      _requireUtc(receipt.rewardedAt!, 'rewardedAt');
    }
    _requireUtc(now, 'now');
    final changed = await _database.update(
      'lesson_completion_results',
      {
        'sync_status': 'synced',
        'next_sync_attempt_at': null,
        'last_sync_error_code': null,
        'sync_updated_at': now.toIso8601String(),
        'server_accepted_at': receipt.acceptedAt.toIso8601String(),
        'reward_status': _encodeRewardStatus(receipt.rewardStatus),
        'reward_yuzu': receipt.rewardYuzu,
        'weekly_yuzu': receipt.weeklyYuzu,
        'completion_ordinal': receipt.completionOrdinal,
        'reward_timing': _encodeRewardTiming(receipt.rewardTiming),
        'rewarded_at': receipt.rewardedAt?.toIso8601String(),
      },
      where: "id = ? AND user_id = ? AND sync_status = 'syncing'",
      whereArgs: [resultId, userId],
    );
    if (changed != 1) throw StateError('Syncing lesson result not found');
    _changes.add(userId);
  }

  @override
  Future<void> markSyncFailed({
    required String userId,
    required String resultId,
    required String errorCode,
    required DateTime? retryAt,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    if (retryAt != null) _requireUtc(retryAt, 'retryAt');
    final changed = await _database.update(
      'lesson_completion_results',
      {
        'sync_status': 'failed',
        'next_sync_attempt_at': retryAt?.toIso8601String(),
        'last_sync_error_code': errorCode,
        'sync_updated_at': now.toIso8601String(),
      },
      where: "id = ? AND user_id = ? AND sync_status = 'syncing'",
      whereArgs: [resultId, userId],
    );
    if (changed != 1) throw StateError('Syncing lesson result not found');
    _changes.add(userId);
  }

  @override
  Future<int> recoverInterruptedSyncs({
    required String userId,
    required DateTime interruptedBefore,
    required DateTime now,
  }) async {
    _requireUtc(interruptedBefore, 'interruptedBefore');
    _requireUtc(now, 'now');
    final changed = await _database.update(
      'lesson_completion_results',
      {
        'sync_status': 'failed',
        'next_sync_attempt_at': now.toIso8601String(),
        'last_sync_error_code': 'interrupted',
        'sync_updated_at': now.toIso8601String(),
      },
      where: '''
        user_id = ? AND sync_status = 'syncing'
        AND sync_updated_at IS NOT NULL AND sync_updated_at <= ?
      ''',
      whereArgs: [userId, interruptedBefore.toIso8601String()],
    );
    if (changed > 0) _changes.add(userId);
    return changed;
  }

  Future<void> retryFailed({
    required String userId,
    required String resultId,
    required DateTime now,
  }) async {
    _requireUtc(now, 'now');
    final changed = await _database.update(
      'lesson_completion_results',
      {
        'sync_status': 'pending',
        'next_sync_attempt_at': null,
        'last_sync_error_code': null,
        'sync_updated_at': now.toIso8601String(),
      },
      where: "id = ? AND user_id = ? AND sync_status = 'failed'",
      whereArgs: [resultId, userId],
    );
    if (changed != 1) throw StateError('Failed lesson result not found');
    _changes.add(userId);
  }

  static Future<LessonSession?> _getSession(
    DatabaseExecutor database, {
    required String userId,
    required String sessionId,
  }) async {
    final rows = await database.query(
      'lesson_sessions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [sessionId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeSession(database, rows.single);
  }

  static Future<LessonSession> _decodeSession(
    DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final itemMaps = (jsonDecode(row['snapshot_json']! as String) as List)
        .cast<Map<String, Object?>>();
    final items = itemMaps.map(_itemFromMap).toList(growable: false);
    final attempts = await database.query(
      'lesson_attempts',
      where: 'session_id = ? AND user_id = ?',
      whereArgs: [row['id'], row['user_id']],
      orderBy: 'occurred_at ASC, id ASC',
    );
    final decodedAttempts = {
      for (final attemptRow in attempts)
        attemptRow['id']! as String: _attemptFromMap(attemptRow),
    };
    return LessonSession(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      missionDate: _decodeDay(row['mission_date'] as String?),
      mode: _decodeMode(row['mode']! as String),
      status: _decodeStatus(row['status']! as String),
      items: items,
      mastery: LessonMasteryState(
        itemIds: items.map((item) => item.id),
        pendingQueue: _decodeStringList(
          row['pending_queue_json']! as String,
        ),
        masteredItemIds: _decodeStringList(
          row['mastered_item_ids_json']! as String,
        ),
        attempts: decodedAttempts,
      ),
      currentQuestionJson: row['current_question_json'] as String?,
      draftJson: row['draft_json'] as String?,
      sourceRevisionHash: row['source_revision_hash']! as String,
      ruleVersion: row['rule_version']! as String,
      normalizerVersion: row['normalizer_version']! as String,
      rewardEligible: row['reward_eligible'] == 1,
      startsAt: _decodeUtc(row['starts_at']! as String),
      endsAt: _decodeUtc(row['ends_at']! as String),
      nextDayEndsAt: _decodeUtc(row['next_day_ends_at']! as String),
      startedAt: _decodeUtc(row['started_at']! as String),
      updatedAt: _decodeUtc(row['updated_at']! as String),
      completedAt: _decodeOptionalUtc(row['completed_at'] as String?),
      abandonedAt: _decodeOptionalUtc(row['abandoned_at'] as String?),
    );
  }

  static Future<LessonCompletionResult?> _getCompletion(
    DatabaseExecutor database, {
    required String userId,
    required String sessionId,
  }) async {
    final rows = await database.query(
      'lesson_completion_results',
      where: 'session_id = ? AND user_id = ?',
      whereArgs: [sessionId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _completionFromMap(rows.single);
  }

  static Future<LessonCompletionResult?> _getCompletionById(
    DatabaseExecutor database, {
    required String userId,
    required String resultId,
  }) async {
    final rows = await database.query(
      'lesson_completion_results',
      where: 'id = ? AND user_id = ?',
      whereArgs: [resultId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _completionFromMap(rows.single);
  }

  Future<LessonCompletionSyncPayload?> _syncPayload({
    required String userId,
    required String resultId,
  }) async {
    final rows = await _database.rawQuery('''
      SELECT
        result.*,
        session.rule_version,
        session.normalizer_version,
        session.snapshot_json,
        session.reward_eligible
      FROM lesson_completion_results AS result
      JOIN lesson_sessions AS session
        ON session.id = result.session_id
       AND session.user_id = result.user_id
      WHERE result.id = ? AND result.user_id = ?
      LIMIT 1
    ''', [resultId, userId]);
    if (rows.isEmpty || rows.single['reward_eligible'] != 1) return null;
    final row = rows.single;
    final result = _completionFromMap(row);
    if (result.missionDate == null ||
        result.syncStatus == LessonCompletionSyncStatus.notApplicable) {
      return null;
    }
    final snapshot = (jsonDecode(row['snapshot_json']! as String) as List)
        .cast<Map<String, Object?>>();
    final attempts = await _database.query(
      'lesson_attempts',
      where: 'session_id = ? AND user_id = ?',
      whereArgs: [result.sessionId, userId],
      orderBy: 'occurred_at ASC, id ASC',
    );
    return LessonCompletionSyncPayload(
      result: result,
      ruleVersion: row['rule_version']! as String,
      normalizerVersion: row['normalizer_version']! as String,
      evidence: {
        'items': [
          for (final item in snapshot)
            {
              'id': item['id'],
              'photo_note_id': item['photo_note_id'],
              'media_asset_id': item['media_asset_id'],
              'target_id': item['target_id'],
              'source_revision': item['source_revision'],
            },
        ],
        'attempts': [
          for (final attempt in attempts)
            {
              'id': attempt['id'],
              'question_id': attempt['question_id'],
              'game_type': attempt['game_type'],
              'verdicts': jsonDecode(attempt['verdict_json']! as String),
            },
        ],
      },
    );
  }

  static Map<String, Object?> _sessionToMap(LessonSession session) => {
        'id': session.id,
        'user_id': session.userId,
        'mission_date': session.missionDate == null
            ? null
            : _encodeDay(session.missionDate!),
        'mode': _encodeMode(session.mode),
        'status': _encodeStatus(session.status),
        'total_items': session.mastery.totalCount,
        'completed_items': session.mastery.completedCount,
        'snapshot_json': jsonEncode(
          session.items.map(_itemToMap).toList(growable: false),
        ),
        'pending_queue_json': jsonEncode(session.mastery.pendingQueue),
        'mastered_item_ids_json': jsonEncode(
          session.mastery.masteredItemIds.toList()..sort(),
        ),
        'current_question_json': session.currentQuestionJson,
        'draft_json': session.draftJson,
        'source_revision_hash': session.sourceRevisionHash,
        'rule_version': session.ruleVersion,
        'normalizer_version': session.normalizerVersion,
        'reward_eligible': session.rewardEligible ? 1 : 0,
        'starts_at': session.startsAt.toIso8601String(),
        'ends_at': session.endsAt.toIso8601String(),
        'next_day_ends_at': session.nextDayEndsAt.toIso8601String(),
        'started_at': session.startedAt.toIso8601String(),
        'updated_at': session.updatedAt.toIso8601String(),
        'completed_at': session.completedAt?.toIso8601String(),
        'abandoned_at': session.abandonedAt?.toIso8601String(),
      };

  static Map<String, Object?> _attemptToMap({
    required String userId,
    required String sessionId,
    required LessonGradedAttempt attempt,
    required DateTime occurredAt,
  }) =>
      {
        'id': attempt.attemptId,
        'session_id': sessionId,
        'user_id': userId,
        'question_id': attempt.questionId,
        'game_type': _encodeGameType(attempt.gameType),
        'payload_fingerprint': attempt.payloadFingerprint,
        'verdict_json': jsonEncode([
          for (final verdict in attempt.verdicts)
            {'item_id': verdict.itemId, 'is_correct': verdict.isCorrect},
        ]),
        'occurred_at': occurredAt.toIso8601String(),
      };

  static LessonGradedAttempt _attemptFromMap(Map<String, Object?> row) {
    final verdicts = (jsonDecode(row['verdict_json']! as String) as List)
        .cast<Map<String, Object?>>();
    return LessonGradedAttempt(
      attemptId: row['id']! as String,
      questionId: row['question_id']! as String,
      gameType: _decodeGameType(row['game_type']! as String),
      payloadFingerprint: row['payload_fingerprint']! as String,
      verdicts: [
        for (final verdict in verdicts)
          LessonItemVerdict(
            itemId: verdict['item_id']! as String,
            isCorrect: verdict['is_correct']! as bool,
          ),
      ],
    );
  }

  static Map<String, Object?> _itemToMap(LessonMasteryItem item) => {
        'id': item.id,
        'photo_note_id': item.photoNoteId,
        'media_asset_id': item.mediaAssetId,
        'image_relative_path': item.imageRelativePath,
        'image_width': item.imageWidth,
        'image_height': item.imageHeight,
        'target_id': item.targetId,
        'bounding_box': {
          'x': item.boundingBox.x,
          'y': item.boundingBox.y,
          'width': item.boundingBox.width,
          'height': item.boundingBox.height,
        },
        'answer': item.answer,
        'source_revision': item.sourceRevision,
      };

  static LessonMasteryItem _itemFromMap(Map<String, Object?> row) {
    final box = (row['bounding_box']! as Map).cast<String, Object?>();
    return LessonMasteryItem(
      id: row['id']! as String,
      photoNoteId: row['photo_note_id']! as String,
      mediaAssetId: row['media_asset_id']! as String,
      imageRelativePath: row['image_relative_path']! as String,
      imageWidth: row['image_width']! as int,
      imageHeight: row['image_height']! as int,
      targetId: row['target_id']! as String,
      boundingBox: LessonNormalizedBoundingBox(
        x: (box['x']! as num).toDouble(),
        y: (box['y']! as num).toDouble(),
        width: (box['width']! as num).toDouble(),
        height: (box['height']! as num).toDouble(),
      ),
      answer: row['answer']! as String,
      sourceRevision: row['source_revision']! as String,
    );
  }

  static LessonCompletionResult _completionFromMap(
    Map<String, Object?> row,
  ) =>
      LessonCompletionResult(
        id: row['id']! as String,
        sessionId: row['session_id']! as String,
        userId: row['user_id']! as String,
        missionDate: _decodeDay(row['mission_date'] as String?),
        totalItems: row['total_items']! as int,
        completedItems: row['completed_items']! as int,
        sourceRevisionHash: row['source_revision_hash']! as String,
        completedAt: _decodeUtc(row['completed_at']! as String),
        createdAt: _decodeUtc(row['created_at']! as String),
        syncStatus: _decodeSyncStatus(row['sync_status']! as String),
        syncAttemptCount: row['sync_attempt_count']! as int,
        nextSyncAttemptAt:
            _decodeOptionalUtc(row['next_sync_attempt_at'] as String?),
        lastSyncErrorCode: row['last_sync_error_code'] as String?,
        serverAcceptedAt:
            _decodeOptionalUtc(row['server_accepted_at'] as String?),
        rewardStatus: _decodeRewardStatus(row['reward_status']! as String),
        rewardYuzu: row['reward_yuzu'] as int?,
        weeklyYuzu: row['weekly_yuzu'] as int?,
        completionOrdinal: row['completion_ordinal'] as int?,
        rewardTiming: row['reward_timing'] == null
            ? null
            : _decodeRewardTiming(row['reward_timing']! as String),
        rewardedAt: _decodeOptionalUtc(row['rewarded_at'] as String?),
      );

  static LessonCompletionSyncStatus _decodeSyncStatus(String value) =>
      switch (value) {
        'not_applicable' => LessonCompletionSyncStatus.notApplicable,
        'pending' => LessonCompletionSyncStatus.pending,
        'syncing' => LessonCompletionSyncStatus.syncing,
        'synced' => LessonCompletionSyncStatus.synced,
        'failed' => LessonCompletionSyncStatus.failed,
        _ => throw FormatException('Unsupported lesson sync status: $value'),
      };

  static String _encodeRewardStatus(LessonRewardStatus status) =>
      switch (status) {
        LessonRewardStatus.notApplicable => 'not_applicable',
        LessonRewardStatus.pending => 'pending',
        LessonRewardStatus.awarded => 'awarded',
        LessonRewardStatus.rejected => 'rejected',
      };

  static LessonRewardStatus _decodeRewardStatus(String value) =>
      switch (value) {
        'not_applicable' => LessonRewardStatus.notApplicable,
        'pending' => LessonRewardStatus.pending,
        'awarded' => LessonRewardStatus.awarded,
        'rejected' => LessonRewardStatus.rejected,
        _ => throw FormatException('Unsupported lesson reward status: $value'),
      };

  static String _encodeRewardTiming(LessonRewardTiming timing) =>
      switch (timing) {
        LessonRewardTiming.onTime => 'on_time',
        LessonRewardTiming.late => 'late',
        LessonRewardTiming.expired => 'expired',
      };

  static LessonRewardTiming _decodeRewardTiming(String value) =>
      switch (value) {
        'on_time' => LessonRewardTiming.onTime,
        'late' => LessonRewardTiming.late,
        'expired' => LessonRewardTiming.expired,
        _ => throw FormatException('Unsupported lesson reward timing: $value'),
      };

  static int _projectedYuzu(int completedItems, int targetWords) {
    if (completedItems < targetWords) return 0;
    if (completedItems >= targetWords * 2) return 150;
    if (completedItems * 2 >= targetWords * 3) return 130;
    return 100;
  }

  static List<String> _decodeStringList(String value) =>
      (jsonDecode(value) as List).cast<String>();

  static String _encodeMode(LessonSessionMode mode) => switch (mode) {
        LessonSessionMode.daily => 'daily',
        LessonSessionMode.review => 'review',
      };

  static LessonSessionMode _decodeMode(String value) => switch (value) {
        'daily' => LessonSessionMode.daily,
        'review' => LessonSessionMode.review,
        _ => throw FormatException('Unsupported lesson session mode: $value'),
      };

  static String _encodeStatus(LessonSessionStatus status) => switch (status) {
        LessonSessionStatus.active => 'active',
        LessonSessionStatus.paused => 'paused',
        LessonSessionStatus.blocked => 'blocked',
        LessonSessionStatus.completed => 'completed',
        LessonSessionStatus.abandoned => 'abandoned',
        LessonSessionStatus.expired => 'expired',
      };

  static LessonSessionStatus _decodeStatus(String value) => switch (value) {
        'active' => LessonSessionStatus.active,
        'paused' => LessonSessionStatus.paused,
        'blocked' => LessonSessionStatus.blocked,
        'completed' => LessonSessionStatus.completed,
        'abandoned' => LessonSessionStatus.abandoned,
        'expired' => LessonSessionStatus.expired,
        _ => throw FormatException('Unsupported lesson status: $value'),
      };

  static String _encodeGameType(LessonGameType gameType) => switch (gameType) {
        LessonGameType.photoOrderQuiz => 'photo_order_quiz',
        LessonGameType.photoLetterFill => 'photo_letter_fill',
      };

  static LessonGameType _decodeGameType(String value) => switch (value) {
        'photo_order_quiz' => LessonGameType.photoOrderQuiz,
        'photo_letter_fill' => LessonGameType.photoLetterFill,
        _ => throw FormatException('Unsupported lesson game type: $value'),
      };

  static String _encodeDay(DateTime day) {
    if (!day.isUtc || day != DateTime.utc(day.year, day.month, day.day)) {
      throw ArgumentError.value(day, 'day', 'must be a UTC calendar date');
    }
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _decodeDay(String? value) =>
      value == null ? null : DateTime.parse('${value}T00:00:00.000Z');

  static DateTime _decodeUtc(String value) => DateTime.parse(value).toUtc();

  static DateTime? _decodeOptionalUtc(String? value) =>
      value == null ? null : _decodeUtc(value);

  static void _requireUtc(DateTime value, String name) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, name, 'must be UTC');
    }
  }

  static void _validateOptionalJson(String? value, String name) {
    if (value == null) {
      return;
    }
    try {
      jsonDecode(value);
    } on FormatException {
      throw ArgumentError.value(value, name, 'must be valid JSON');
    }
  }
}
