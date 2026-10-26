import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_gateway.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_worker.dart';
import 'package:capy_vocab/features/mini_games/data/local/sqlite_lesson_session_store.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_game.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '20000000-0000-0000-0000-000000000001';
const _otherUserId = '20000000-0000-0000-0000-000000000002';
const _day = '2026-09-02';
final _missionDate = DateTime.utc(2026, 9, 2);
final _startsAt = DateTime.utc(2026, 9, 1, 17);
final _endsAt = DateTime.utc(2026, 9, 2, 17);
final _nextDayEndsAt = DateTime.utc(2026, 9, 3, 17);

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteLessonSessionStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('capy_h3b_');
    databasePath =
        '${tempDirectory.path}${Platform.pathSeparator}library_test.db';
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    database = await libraryDatabase.open();
    await _insertAccount(database, _userId);
    await _insertAccount(database, _otherUserId);
    await _insertDailyMission(database, _userId);
    store = SqliteLessonSessionStore(database);
  });

  tearDown(() async {
    await libraryDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await tempDirectory.delete(recursive: true);
  });

  test('stores an owner-scoped frozen session snapshot', () async {
    final session = _session();
    await store.create(session);

    final loaded = await store.get(userId: _userId, sessionId: session.id);
    final crossOwner = await store.get(
      userId: _otherUserId,
      sessionId: session.id,
    );

    expect(loaded, isNotNull);
    expect(loaded!.items.map((item) => item.answer), ['Apple', 'Cup']);
    expect(loaded.mastery.pendingQueue, ['item-apple', 'item-cup']);
    expect(crossOwner, isNull);
    await expectLater(
      database.update(
        'lesson_sessions',
        {'snapshot_json': '[]'},
        where: 'id = ?',
        whereArgs: [session.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('restores a paused draft and commits completion exactly once', () async {
    final session = _session();
    await store.create(session);

    final wrong = await store.applyAttempt(
      userId: _userId,
      sessionId: session.id,
      attempt: _attempt(
        id: 'attempt-wrong',
        itemId: 'item-apple',
        isCorrect: false,
      ),
      now: DateTime.utc(2026, 9, 2, 2, 1),
    );
    expect(wrong.session.mastery.pendingQueue, ['item-cup', 'item-apple']);
    expect(wrong.completion, isNull);

    await store.pause(
      userId: _userId,
      sessionId: session.id,
      currentQuestionJson: '{"question":"fill-1"}',
      draftJson: '{"answer":"ap"}',
      now: DateTime.utc(2026, 9, 2, 2, 2),
    );
    await libraryDatabase.close();
    database = await libraryDatabase.open();
    store = SqliteLessonSessionStore(database);

    final restored = await store.get(userId: _userId, sessionId: session.id);
    expect(restored!.status, LessonSessionStatus.paused);
    expect(restored.currentQuestionJson, '{"question":"fill-1"}');
    expect(restored.draftJson, '{"answer":"ap"}');
    expect(restored.mastery.pendingQueue, ['item-cup', 'item-apple']);

    await store.resume(
      userId: _userId,
      sessionId: session.id,
      now: DateTime.utc(2026, 9, 2, 2, 3),
    );
    final partial = await store.applyAttempt(
      userId: _userId,
      sessionId: session.id,
      attempt: _attempt(
        id: 'attempt-cup-correct',
        itemId: 'item-cup',
        isCorrect: true,
      ),
      now: DateTime.utc(2026, 9, 2, 2, 4),
    );
    expect(partial.session.mastery.completedCount, 1);
    expect(partial.completion, isNull, reason: '50% is not completion');

    final finalAttempt = _attempt(
      id: 'attempt-apple-correct',
      itemId: 'item-apple',
      isCorrect: true,
    );
    final completed = await store.applyAttempt(
      userId: _userId,
      sessionId: session.id,
      attempt: finalAttempt,
      now: DateTime.utc(2026, 9, 2, 2, 5),
    );
    expect(completed.session.status, LessonSessionStatus.completed);
    expect(completed.completion, isNotNull);
    expect(completed.completion!.completedItems, 2);
    expect(
      completed.completion!.syncStatus,
      LessonCompletionSyncStatus.pending,
    );

    final replay = await store.applyAttempt(
      userId: _userId,
      sessionId: session.id,
      attempt: finalAttempt,
      now: DateTime.utc(2026, 9, 2, 2, 6),
    );
    expect(replay.application.isReplay, isTrue);
    expect(replay.completion!.id, completed.completion!.id);
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM lesson_completion_results',
        ),
      ),
      1,
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM lesson_attempts'),
      ),
      3,
    );
  });

  test('rejects a conflicting retry without changing persisted progress',
      () async {
    final session = _session();
    await store.create(session);
    final original = _attempt(
      id: 'attempt-retry',
      itemId: 'item-apple',
      isCorrect: false,
    );
    await store.applyAttempt(
      userId: _userId,
      sessionId: session.id,
      attempt: original,
      now: DateTime.utc(2026, 9, 2, 2, 1),
    );

    await expectLater(
      store.applyAttempt(
        userId: _userId,
        sessionId: session.id,
        attempt: LessonGradedAttempt(
          attemptId: original.attemptId,
          questionId: original.questionId,
          gameType: original.gameType,
          payloadFingerprint: 'different-payload',
          verdicts: const [
            LessonItemVerdict(itemId: 'item-apple', isCorrect: true),
          ],
        ),
        now: DateTime.utc(2026, 9, 2, 2, 2),
      ),
      throwsA(isA<LessonAttemptConflict>()),
    );
    final restored = await store.get(userId: _userId, sessionId: session.id);
    expect(restored!.mastery.completedCount, 0);
    expect(restored.mastery.attempts, hasLength(1));
  });

  test('abandoning preserves progress and draft but disables rewards',
      () async {
    final session = _session();
    await store.create(session);
    await store.saveDraft(
      userId: _userId,
      sessionId: session.id,
      currentQuestionJson: '{"question":"order-1"}',
      draftJson: '{"slots":["item-apple"]}',
      now: DateTime.utc(2026, 9, 2, 2, 1),
    );

    final abandoned = await store.abandon(
      userId: _userId,
      sessionId: session.id,
      now: DateTime.utc(2026, 9, 2, 2, 2),
    );

    expect(abandoned.status, LessonSessionStatus.abandoned);
    expect(abandoned.rewardEligible, isFalse);
    expect(abandoned.mastery.pendingQueue, ['item-apple', 'item-cup']);
    expect(abandoned.draftJson, '{"slots":["item-apple"]}');
    await expectLater(
      store.applyAttempt(
        userId: _userId,
        sessionId: session.id,
        attempt: _attempt(
          id: 'attempt-after-abandon',
          itemId: 'item-apple',
          isCorrect: true,
        ),
        now: DateTime.utc(2026, 9, 2, 2, 3),
      ),
      throwsStateError,
    );
  });

  test('syncs a daily completion once and survives database reopen', () async {
    final completion = await _completeSession(store);
    expect(completion.syncStatus, LessonCompletionSyncStatus.pending);
    expect(await store.outstandingSyncCount(_userId), 1);
    expect(await store.pendingYuzuEstimate(_userId), 100);

    final payloads = await store.readySyncPayloads(
      userId: _userId,
      now: DateTime.utc(2026, 9, 2, 3),
    );
    expect(payloads, hasLength(1));
    final evidenceText = payloads.single.evidence.toString();
    expect(evidenceText, isNot(contains('capy_scans')));
    expect(evidenceText, contains('word: Apple'));
    expect(evidenceText, isNot(contains('item-apple-true')));

    final gateway = _FakeGateway(userId: _userId);
    final worker = LessonCompletionSyncWorker(
      store: store,
      gateway: gateway,
      clock: () => DateTime.utc(2026, 9, 2, 3),
    );
    final first = await worker.drainOnce(userId: _userId);
    expect(first.synced, 1);
    expect(gateway.calls, 1);
    expect(await store.outstandingSyncCount(_userId), 0);
    expect(await store.pendingYuzuEstimate(_userId), 0);

    await libraryDatabase.close();
    database = await libraryDatabase.open();
    store = SqliteLessonSessionStore(database);
    final reopened = await store.getCompletion(
      userId: _userId,
      sessionId: 'session-1',
    );
    expect(reopened!.syncStatus, LessonCompletionSyncStatus.synced);
    expect(reopened.serverAcceptedAt, DateTime.utc(2026, 9, 2, 3));
    expect(reopened.rewardStatus, LessonRewardStatus.awarded);
    expect(reopened.rewardYuzu, 100);
    expect(reopened.weeklyYuzu, 100);
    expect(reopened.completionOrdinal, 1);
    expect(reopened.rewardTiming, LessonRewardTiming.onTime);
    expect(reopened.rewardedAt, DateTime.utc(2026, 9, 2, 3));

    final secondWorker = LessonCompletionSyncWorker(
      store: store,
      gateway: gateway,
      clock: () => DateTime.utc(2026, 9, 2, 3, 1),
    );
    final second = await secondWorker.drainOnce(userId: _userId);
    expect(second.synced, 0);
    expect(gateway.calls, 1, reason: 'a synced receipt is never sent twice');
  });

  test('keeps a retryable failure and later syncs without losing completion',
      () async {
    await _completeSession(store);
    var now = DateTime.utc(2026, 9, 2, 3);
    final gateway = _FakeGateway(
      userId: _userId,
      failures: 1,
    );
    final worker = LessonCompletionSyncWorker(
      store: store,
      gateway: gateway,
      clock: () => now,
    );

    final failed = await worker.drainOnce(userId: _userId);
    expect(failed.retried, 1);
    var completion = await store.getCompletion(
      userId: _userId,
      sessionId: 'session-1',
    );
    expect(completion!.syncStatus, LessonCompletionSyncStatus.failed);
    expect(completion.lastSyncErrorCode, 'temporary_network');
    expect(completion.nextSyncAttemptAt, now.add(const Duration(seconds: 5)));
    expect(completion.completedItems, 2);

    now = now.add(const Duration(seconds: 5));
    final recovered = await worker.drainOnce(userId: _userId);
    expect(recovered.synced, 1);
    completion = await store.getCompletion(
      userId: _userId,
      sessionId: 'session-1',
    );
    expect(completion!.syncStatus, LessonCompletionSyncStatus.synced);
    expect(gateway.calls, 2);
  });
}

Future<LessonCompletionResult> _completeSession(
  SqliteLessonSessionStore store,
) async {
  final session = _session();
  await store.create(session);
  await store.applyAttempt(
    userId: _userId,
    sessionId: session.id,
    attempt: _attempt(
      id: 'attempt-apple-correct',
      itemId: 'item-apple',
      isCorrect: true,
    ),
    now: DateTime.utc(2026, 9, 2, 2, 1),
  );
  final completed = await store.applyAttempt(
    userId: _userId,
    sessionId: session.id,
    attempt: _attempt(
      id: 'attempt-cup-correct',
      itemId: 'item-cup',
      isCorrect: true,
    ),
    now: DateTime.utc(2026, 9, 2, 2, 2),
  );
  return completed.completion!;
}

final class _FakeGateway implements LessonCompletionSyncGateway {
  _FakeGateway({required this.userId, this.failures = 0});

  final String userId;
  int failures;
  int calls = 0;

  @override
  String? get authenticatedUserId => userId;

  @override
  Future<LessonCompletionReceipt> sync(
    LessonCompletionSyncPayload payload,
  ) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const LessonSyncFailure.retry('temporary_network');
    }
    return LessonCompletionReceipt(
      resultId: payload.result.id,
      userId: userId,
      acceptedAt: DateTime.utc(2026, 9, 2, 3),
      rewardStatus: LessonRewardStatus.awarded,
      rewardYuzu: 100,
      weeklyYuzu: 100,
      completionOrdinal: 1,
      rewardTiming: LessonRewardTiming.onTime,
      rewardedAt: DateTime.utc(2026, 9, 2, 3),
    );
  }
}

LessonSession _session() => LessonSession.daily(
      id: 'session-1',
      userId: _userId,
      missionDate: _missionDate,
      items: [
        LessonMasteryItem(
          id: 'item-apple',
          photoNoteId: 'note-1',
          mediaAssetId: 'media-1',
          imageRelativePath: 'capy_scans/media-1.jpg',
          imageWidth: 100,
          imageHeight: 100,
          targetId: 'target-1',
          boundingBox: LessonNormalizedBoundingBox(
            x: 0.1,
            y: 0.1,
            width: 0.2,
            height: 0.2,
          ),
          answer: 'Apple',
          sourceRevision: 'revision-1',
        ),
        LessonMasteryItem(
          id: 'item-cup',
          photoNoteId: 'note-1',
          mediaAssetId: 'media-1',
          imageRelativePath: 'capy_scans/media-1.jpg',
          imageWidth: 100,
          imageHeight: 100,
          targetId: 'target-2',
          boundingBox: LessonNormalizedBoundingBox(
            x: 0.5,
            y: 0.5,
            width: 0.2,
            height: 0.2,
          ),
          answer: 'Cup',
          sourceRevision: 'revision-1',
        ),
      ],
      sourceRevisionHash: 'snapshot-hash-1',
      ruleVersion: 'h3-rules-v1',
      startsAt: _startsAt,
      endsAt: _endsAt,
      nextDayEndsAt: _nextDayEndsAt,
      startedAt: DateTime.utc(2026, 9, 2, 2),
    );

LessonGradedAttempt _attempt({
  required String id,
  required String itemId,
  required bool isCorrect,
}) =>
    LessonGradedAttempt(
      attemptId: id,
      questionId: 'question-$id',
      gameType: LessonGameType.photoLetterFill,
      payloadFingerprint: '$itemId-$isCorrect',
      verdicts: [
        LessonItemVerdict(itemId: itemId, isCorrect: isCorrect),
      ],
    );

Future<void> _insertAccount(Database database, String userId) {
  const timestamp = '2026-09-02T02:00:00.000Z';
  return database.insert('local_accounts', {
    'user_id': userId,
    'account_state': 'active',
    'cloud_backup_enabled': 0,
    'local_personalization_enabled': 0,
    'federated_contribution_enabled': 0,
    'created_at': timestamp,
    'updated_at': timestamp,
  });
}

Future<void> _insertDailyMission(Database database, String userId) {
  return database.insert('daily_missions', {
    'user_id': userId,
    'mission_date': _day,
    'time_zone': 'Asia/Bangkok',
    'target_words': 2,
    'created_at': '2026-09-02T02:00:00.000Z',
    'starts_at': _startsAt.toIso8601String(),
    'ends_at': _endsAt.toIso8601String(),
    'next_day_ends_at': _nextDayEndsAt.toIso8601String(),
    'sync_status': 'local_only',
  });
}
