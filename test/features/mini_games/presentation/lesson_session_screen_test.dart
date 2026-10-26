import 'dart:convert';
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
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:capy_vocab/core/theme/app_theme.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_gateway.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_session_controller.dart';
import 'package:capy_vocab/features/mini_games/data/local/sqlite_lesson_session_store.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_session.dart';
import 'package:capy_vocab/features/mini_games/presentation/providers/lesson_completion_sync_provider.dart';
import 'package:capy_vocab/features/mini_games/presentation/providers/lesson_session_provider.dart';
import 'package:capy_vocab/features/mini_games/presentation/screens/lesson_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '00000000-0000-4000-8000-000000000001';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _day = DateTime.utc(2026, 9, 29);
final _startsAt = DateTime.utc(2026, 9, 28, 17);
final _endsAt = DateTime.utc(2026, 9, 29, 17);
final _nextDayEndsAt = DateTime.utc(2026, 9, 30, 17);
final _now = DateTime.utc(2026, 9, 29, 2);

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('lesson shell completes both items and renders result',
      (tester) async {
    late Directory tempDirectory;
    late String databasePath;
    late LibraryDatabase libraryDatabase;
    late Database database;
    late SqliteLessonSessionStore store;
    await tester.runAsync(() async {
      tempDirectory = await Directory.systemTemp.createTemp('capy_h3d_screen_');
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
    });
    addTearDown(() async {
      await libraryDatabase.close();
      await databaseFactoryFfi.deleteDatabase(databasePath);
      await tempDirectory.delete(recursive: true);
    });
    final snapshot = _snapshot();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLibraryUserIdProvider.overrideWith((ref) => _userId),
          libraryRepositoryProvider.overrideWith(
            (ref) async => _FakeRepository(snapshot),
          ),
          libraryMediaLoaderProvider.overrideWithValue(
            const _MemoryMediaLoader(),
          ),
          lessonSessionStoreProvider.overrideWith((ref) async => store),
          lessonCompletionSyncCoordinatorProvider
              .overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LessonSessionScreen(
            request: DailyLessonStartRequest(
              userId: _userId,
              missionDate: _day,
              photoNoteIds: [snapshot.photoNote.id],
              targetWords: 2,
              ruleVersion: 'h3-rules-v1',
              startsAt: _startsAt,
              endsAt: _endsAt,
              nextDayEndsAt: _nextDayEndsAt,
              now: _now,
            ),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Ghép từ với đồ vật'));

    expect(find.text('Ghép từ với đồ vật'), findsOneWidget);
    expect(find.text('0/2 từ'), findsOneWidget);
    final heading = tester.renderObject<RenderParagraph>(
      find.text('Ghép từ với đồ vật'),
    );
    expect(heading.text.style!.color!.computeLuminance(), lessThan(0.5));
    final apple = find.byKey(Key('photo-order-card-${_uuid(4)}'));
    final cup = find.byKey(Key('photo-order-card-${_uuid(5)}'));
    final firstSlot = find.byKey(const Key('photo-order-slot-1'));
    final secondSlot = find.byKey(const Key('photo-order-slot-2'));
    await tester.ensureVisible(apple);
    await tester.tap(apple);
    await tester.pump();
    await tester.ensureVisible(firstSlot);
    await tester.tap(firstSlot);
    await tester.pump();
    await tester.ensureVisible(cup);
    await tester.tap(cup);
    await tester.pump();
    await tester.ensureVisible(secondSlot);
    await tester.tap(secondSlot);
    await tester.pump();
    final submit = find.byKey(const Key('photo-order-submit'));
    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.byKey(const Key('lesson-feedback')));

    expect(find.byKey(const Key('lesson-feedback')), findsOneWidget);
    expect(find.text('2/2 từ đúng'), findsOneWidget);
    final continueButton = find.byKey(const Key('lesson-feedback-continue'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('lesson-completion-pending')),
    );

    expect(find.text('Đã hoàn thành — chờ đồng bộ'), findsOneWidget);
    expect(find.textContaining('chưa thể chi tiêu'), findsOneWidget);
    final completion = await tester.runAsync(() async {
      final rows = await database.query(
        'lesson_completion_results',
        columns: ['session_id'],
        limit: 1,
      );
      return store.getCompletion(
        userId: _userId,
        sessionId: rows.single['session_id']! as String,
      );
    });
    final resultId = completion!.id;
    await tester.runAsync(() async {
      await store.markSyncing(
        userId: _userId,
        resultId: resultId,
        now: DateTime.utc(2026, 9, 29, 3),
      );
      await store.markSyncFailed(
        userId: _userId,
        resultId: resultId,
        errorCode: 'temporary_network',
        retryAt: null,
        now: DateTime.utc(2026, 9, 29, 3),
      );
    });
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('lesson-completion-sync-failed')),
    );
    expect(find.text('Đồng bộ lỗi'), findsOneWidget);
    await tester.tap(find.text('Thử đồng bộ lại'));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('lesson-completion-pending')),
    );

    await tester.runAsync(() async {
      await store.markSyncing(
        userId: _userId,
        resultId: resultId,
        now: DateTime.utc(2026, 9, 29, 3, 1),
      );
      await store.markSynced(
        userId: _userId,
        resultId: resultId,
        receipt: LessonCompletionReceipt(
          resultId: resultId,
          userId: _userId,
          acceptedAt: DateTime.utc(2026, 9, 29, 3, 1),
          rewardStatus: LessonRewardStatus.awarded,
          rewardYuzu: 100,
          weeklyYuzu: 100,
          completionOrdinal: 1,
          rewardTiming: LessonRewardTiming.onTime,
          rewardedAt: DateTime.utc(2026, 9, 29, 3, 1),
        ),
        now: DateTime.utc(2026, 9, 29, 3, 1),
      );
    });
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('lesson-completion-synced')),
    );
    expect(find.text('Đã đồng bộ'), findsOneWidget);
    final completionCount = await tester.runAsync(
      () async => Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM lesson_completion_results',
        ),
      ),
    );
    expect(completionCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  final deadline = Stopwatch()..start();
  while (deadline.elapsed < const Duration(seconds: 30)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

PhotoNoteSnapshot _snapshot() {
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
      createdAt: _now,
      updatedAt: _now,
      syncStatus: SyncStatus.localOnly,
    ),
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: _userId,
      contentHashSha256: _hash,
      displayRelativePath: 'capy_scans/daily.jpg',
      mimeType: 'image/png',
      width: 1,
      height: 1,
      orientation: 0,
      byteSizeDisplay: 100,
      preprocessingVersion: 'v1',
      captureSource: CaptureSource.camera,
      capturedAt: _now,
      createdAt: _now,
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
      startedAt: _now,
      completedAt: _now,
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
        createdAt: _now,
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
        createdAt: _now,
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
    'mission_date': '2026-09-29',
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
  const _FakeRepository(this.snapshot);

  final PhotoNoteSnapshot snapshot;

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async =>
      userId == _userId && photoNoteId == snapshot.photoNote.id
          ? snapshot
          : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemoryMediaLoader implements LibraryMediaLoader {
  const _MemoryMediaLoader();

  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<Uint8List> readBytes(String relativePath) async => _png;

  @override
  Future<int> sizeBytes(String relativePath) async => _png.length;
}
