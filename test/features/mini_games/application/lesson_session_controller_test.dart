import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/normalized_bounding_box.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_question_builder.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_session_controller.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_source_builder.dart';
import 'package:capy_vocab/features/mini_games/data/local/sqlite_lesson_session_store.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '00000000-0000-4000-8000-000000000001';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _day = DateTime.utc(2026, 9, 2);
final _startsAt = DateTime.utc(2026, 9, 1, 17);
final _endsAt = DateTime.utc(2026, 9, 2, 17);
final _nextDayEndsAt = DateTime.utc(2026, 9, 3, 17);
final _now = DateTime.utc(2026, 9, 2, 2);

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteLessonSessionStore store;
  late _FakeRepository repository;
  late _MutableMediaLoader mediaLoader;
  late PhotoNoteSnapshot snapshot;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('capy_h3c_');
    databasePath =
        '${tempDirectory.path}${Platform.pathSeparator}library_test.db';
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    database = await libraryDatabase.open();
    await _insertAccount(database);
    await _insertMission(database);
    store = SqliteLessonSessionStore(database);
    snapshot = _snapshot();
    repository = _FakeRepository({snapshot.photoNote.id: snapshot});
    mediaLoader = _MutableMediaLoader({
      snapshot.mediaAsset.displayRelativePath,
    });
  });

  tearDown(() async {
    await libraryDatabase.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await tempDirectory.delete(recursive: true);
  });

  test('creates a mixed-game session and commits completion after feedback',
      () async {
    final controller = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(controller.dispose);

    await controller.openDaily(_request(targetWords: 2));

    expect(controller.state.phase, LessonFlowPhase.answering);
    expect(controller.state.question, isA<BuiltPhotoOrderQuestion>());
    expect(controller.state.session!.mastery.completedCount, 0);
    expect(
      await store.getCompletion(
        userId: _userId,
        sessionId: controller.state.session!.id,
      ),
      isNull,
    );

    final question = controller.state.question! as BuiltPhotoOrderQuestion;
    await controller.submitOrder({
      for (final target in question.question.targets)
        target.marker: target.itemId,
    });

    expect(controller.state.phase, LessonFlowPhase.feedback);
    expect(controller.state.session!.status, LessonSessionStatus.completed);
    expect(controller.state.feedbackAttempt!.verdicts, hasLength(2));
    expect(
      await store.getCompletion(
        userId: _userId,
        sessionId: controller.state.session!.id,
      ),
      isNotNull,
    );

    controller.continueAfterFeedback();
    expect(controller.state.phase, LessonFlowPhase.completed);
  });

  test('reopens a paused session with the same question, draft and queue',
      () async {
    final first = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    await first.openDaily(_request(targetWords: 2));
    final questionId = first.state.question!.id;
    await first.pause(
      draftJson: '{"selected":"item"}',
      now: _now.add(const Duration(minutes: 1)),
    );
    first.dispose();

    await libraryDatabase.close();
    database = await libraryDatabase.open();
    store = SqliteLessonSessionStore(database);
    final reopened = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(reopened.dispose);
    await reopened.openDaily(
      _request(
        targetWords: 2,
        now: _now.add(const Duration(minutes: 2)),
      ),
    );

    expect(reopened.state.phase, LessonFlowPhase.answering);
    expect(reopened.state.question!.id, questionId);
    expect(reopened.state.session!.draftJson, '{"selected":"item"}');
    expect(reopened.state.session!.mastery.pendingQueue, hasLength(2));
  });

  test('pausing on feedback resumes the next question without the old draft',
      () async {
    final controller = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(controller.dispose);
    await controller.openDaily(_request(targetWords: 2));
    final submitted = controller.state.question! as BuiltPhotoOrderQuestion;
    final reversedItemIds = submitted.question.targets
        .map((target) => target.itemId)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    await controller.submitOrder({
      for (var index = 0; index < submitted.question.targets.length; index++)
        submitted.question.targets[index].marker: reversedItemIds[index],
    });
    expect(controller.state.phase, LessonFlowPhase.feedback);

    await controller.pause(
      draftJson: '{"submitted":"old-question"}',
      now: _now.add(const Duration(minutes: 1)),
    );

    expect(controller.state.phase, LessonFlowPhase.paused);
    expect(controller.state.question!.id, isNot(submitted.id));
    expect(controller.state.session!.draftJson, isNull);

    await controller.resume(now: _now.add(const Duration(minutes: 2)));

    expect(controller.state.phase, LessonFlowPhase.answering);
    expect(controller.state.question!.id, isNot(submitted.id));
    expect(controller.state.session!.draftJson, isNull);
  });

  test('blocks a resumable session when its local image disappears', () async {
    final first = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    await first.openDaily(_request(targetWords: 2));
    await first.pause(now: _now.add(const Duration(minutes: 1)));
    first.dispose();
    mediaLoader.availablePaths.clear();

    final reopened = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(reopened.dispose);
    await reopened.openDaily(
      _request(
        targetWords: 2,
        now: _now.add(const Duration(minutes: 2)),
      ),
    );

    expect(reopened.state.phase, LessonFlowPhase.blocked);
    expect(reopened.state.session!.status, LessonSessionStatus.blocked);
    expect(reopened.state.session!.mastery.pendingQueue, hasLength(2));
  });

  test('does not create a session before enough valid words exist', () async {
    final controller = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(controller.dispose);

    await controller.openDaily(_request(targetWords: 3));

    expect(controller.state.phase, LessonFlowPhase.empty);
    expect(controller.state.source!.items, hasLength(2));
    expect(
      await store.getDaily(userId: _userId, missionDate: _day),
      isNull,
    );
  });

  test('Library review creates a reward-free fill session and result',
      () async {
    final controller = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(controller.dispose);

    await controller.openReview(
      ReviewLessonStartRequest(
        userId: _userId,
        photoNoteIds: [snapshot.photoNote.id],
        preference: LessonGamePreference.fill,
        now: _now,
      ),
    );

    expect(controller.state.phase, LessonFlowPhase.answering);
    expect(controller.state.question, isA<BuiltPhotoLetterFillQuestion>());
    expect(controller.state.session!.mode, LessonSessionMode.review);
    expect(controller.state.session!.missionDate, isNull);
    expect(controller.state.session!.rewardEligible, isFalse);

    while (controller.state.phase != LessonFlowPhase.completed) {
      final question =
          controller.state.question! as BuiltPhotoLetterFillQuestion;
      await controller.submitLetterFill(question.question.expectedAnswer);
      controller.continueAfterFeedback();
    }

    final result = await store.getCompletion(
      userId: _userId,
      sessionId: controller.state.session!.id,
    );
    expect(result, isNotNull);
    expect(result!.missionDate, isNull);
    expect(result.completedItems, 2);
  });

  test('rewarded replay freezes the daily snapshot and queues one-third Yuzu',
      () async {
    final daily = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    await daily.openDaily(_request(targetWords: 2));
    final dailyQuestion = daily.state.question! as BuiltPhotoOrderQuestion;
    await daily.submitOrder({
      for (final target in dailyQuestion.question.targets)
        target.marker: target.itemId,
    });
    daily.continueAfterFeedback();
    expect(daily.state.phase, LessonFlowPhase.completed);
    final frozenItemIds = daily.state.session!.items
        .map((item) => item.id)
        .toList(growable: false);
    daily.dispose();

    final replay = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
      idPrefix: 'replay-',
    );
    addTearDown(replay.dispose);
    await replay.openRewardedReplay(
      RewardedReplayLessonStartRequest(
        userId: _userId,
        missionDate: _day,
        targetWords: 2,
        now: _now.add(const Duration(minutes: 1)),
      ),
    );

    expect(replay.state.phase, LessonFlowPhase.answering);
    expect(replay.state.session!.id, 'session-1:rewarded-replay');
    expect(replay.state.session!.items.map((item) => item.id), frozenItemIds);

    while (replay.state.phase != LessonFlowPhase.completed) {
      final question = replay.state.question;
      if (question is BuiltPhotoOrderQuestion) {
        await replay.submitOrder({
          for (final target in question.question.targets)
            target.marker: target.itemId,
        });
      } else {
        final fill = question! as BuiltPhotoLetterFillQuestion;
        await replay.submitLetterFill(fill.question.expectedAnswer);
      }
      replay.continueAfterFeedback();
    }

    final completion = await store.getCompletion(
      userId: _userId,
      sessionId: replay.state.session!.id,
    );
    expect(completion!.missionDate, _day);
    expect(completion.syncStatus, LessonCompletionSyncStatus.pending);
    expect(completion.rewardStatus, LessonRewardStatus.pending);
    expect(await store.pendingYuzuEstimate(_userId), 133);
  });

  test('third and expired replays remain available without reward', () async {
    final daily = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    await daily.openDaily(_request(targetWords: 2));
    final question = daily.state.question! as BuiltPhotoOrderQuestion;
    await daily.submitOrder({
      for (final target in question.question.targets)
        target.marker: target.itemId,
    });
    daily.continueAfterFeedback();
    daily.dispose();

    final review = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
      idPrefix: 'expired-',
    );
    addTearDown(review.dispose);
    await review.openRewardedReplay(
      RewardedReplayLessonStartRequest(
        userId: _userId,
        missionDate: _day,
        targetWords: 2,
        now: _nextDayEndsAt.add(const Duration(minutes: 1)),
      ),
    );

    expect(review.state.phase, LessonFlowPhase.answering);
    expect(review.state.session!.id, 'expired-session-1');
    expect(review.state.session!.mode, LessonSessionMode.review);
    expect(
      await store.getRewardedReplay(userId: _userId, missionDate: _day),
      isNull,
    );
  });

  test('rejects a stale submission for the wrong game without an attempt',
      () async {
    final controller = _controller(
      store: store,
      repository: repository,
      mediaLoader: mediaLoader,
    );
    addTearDown(controller.dispose);
    await controller.openDaily(_request(targetWords: 2));

    await expectLater(
      controller.submitLetterFill('apple'),
      throwsStateError,
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM lesson_attempts'),
      ),
      0,
    );
  });
}

LessonSessionController _controller({
  required SqliteLessonSessionStore store,
  required LibraryRepository repository,
  required LibraryMediaLoader mediaLoader,
  String idPrefix = '',
}) {
  var question = 0;
  var attempt = 0;
  return LessonSessionController(
    store: store,
    sourceLoader: LessonSourceLoader(
      repository: repository,
      mediaLoader: mediaLoader,
    ),
    sessionIdFactory: () => '${idPrefix}session-1',
    questionIdFactory: () => '${idPrefix}question-${++question}',
    attemptIdFactory: () => '${idPrefix}attempt-${++attempt}',
    now: () => _now.add(const Duration(minutes: 5)),
  );
}

DailyLessonStartRequest _request({
  required int targetWords,
  DateTime? now,
}) =>
    DailyLessonStartRequest(
      userId: _userId,
      missionDate: _day,
      photoNoteIds: [_uuid(1)],
      targetWords: targetWords,
      ruleVersion: 'h3-rules-v1',
      startsAt: _startsAt,
      endsAt: _endsAt,
      nextDayEndsAt: _nextDayEndsAt,
      now: now ?? _now,
    );

PhotoNoteSnapshot _snapshot() {
  final createdAt = _now;
  final noteId = _uuid(1);
  final mediaId = _uuid(2);
  final scanId = _uuid(3);
  return PhotoNoteSnapshot(
    photoNote: PhotoNote(
      id: noteId,
      userId: _userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Daily objects',
      templateId: 'default-v1',
      createdAt: createdAt,
      updatedAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: _userId,
      contentHashSha256: _hash,
      displayRelativePath: 'capy_scans/daily.jpg',
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
      userId: _userId,
      mediaAssetId: mediaId,
      requestId: 'request-1',
      provider: 'test',
      modelName: 'test-model',
      promptVersion: 'v1',
      responseSchemaVersion: 'v1',
      preprocessingVersion: 'v1',
      status: ScanRunStatus.succeeded,
      rawResponseJson: const {
        'words': ['apple', 'cup']
      },
      responseHashSha256: _hash,
      startedAt: createdAt,
      completedAt: createdAt,
    ),
    detections: [
      VocabDetection(
        id: _uuid(4),
        scanRunId: scanId,
        wordRaw: 'Apple',
        wordNormalized: 'apple',
        boundingBox: NormalizedBoundingBox(
          x: 0.1,
          y: 0.1,
          width: 0.2,
          height: 0.2,
        ),
        displayOrder: 0,
        createdAt: createdAt,
      ),
      VocabDetection(
        id: _uuid(5),
        scanRunId: scanId,
        wordRaw: 'Cup',
        wordNormalized: 'cup',
        boundingBox: NormalizedBoundingBox(
          x: 0.5,
          y: 0.5,
          width: 0.2,
          height: 0.2,
        ),
        displayOrder: 1,
        createdAt: createdAt,
      ),
    ],
    annotations: const [],
  );
}

String _uuid(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

Future<void> _insertAccount(Database database) {
  return database.insert('local_accounts', {
    'user_id': _userId,
    'account_state': 'active',
    'cloud_backup_enabled': 0,
    'local_personalization_enabled': 0,
    'federated_contribution_enabled': 0,
    'created_at': _now.toIso8601String(),
    'updated_at': _now.toIso8601String(),
  });
}

Future<void> _insertMission(Database database) {
  return database.insert('daily_missions', {
    'user_id': _userId,
    'mission_date': '2026-09-02',
    'time_zone': 'Asia/Bangkok',
    'target_words': 2,
    'created_at': _now.toIso8601String(),
    'starts_at': _startsAt.toIso8601String(),
    'ends_at': _endsAt.toIso8601String(),
    'next_day_ends_at': _nextDayEndsAt.toIso8601String(),
    'sync_status': 'local_only',
  });
}

final class _FakeRepository implements LibraryRepository {
  _FakeRepository(this.snapshots);

  final Map<String, PhotoNoteSnapshot> snapshots;

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async =>
      userId == _userId ? snapshots[photoNoteId] : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MutableMediaLoader implements LibraryMediaLoader {
  _MutableMediaLoader(this.availablePaths);

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
