import 'dart:async';

import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_session.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/normalized_bounding_box.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const boundary = AccountDayBoundary(Duration(hours: 7));

  test('keeps 23:59 and 00:00 captures in different account days', () {
    final selection = HomeLessonMapSelection(
      period: LessonMapPeriod.month,
      anchorDay: DateTime.utc(2026, 9, 28),
    );
    final overview = buildDailyLessonOverview(
      snapshots: [
        _snapshot(
          seed: 1,
          capturedAt: DateTime.utc(2026, 9, 27, 16, 59),
          words: const ['apple'],
          detectionCreatedAt: DateTime.utc(2026, 9, 27, 18, 30),
        ),
        _snapshot(
          seed: 2,
          capturedAt: DateTime.utc(2026, 9, 27, 17),
          words: const ['banana'],
        ),
      ],
      selection: selection,
      boundary: boundary,
      now: DateTime.utc(2026, 9, 28, 1),
      dailyTarget: 2,
    );

    final september27 = _node(overview, 27);
    final september28 = _node(overview, 28);
    expect(september27.validWords, 1);
    expect(september27.photoCount, 1);
    expect(september27.status, DailyLessonStatus.expired);
    expect(september28.validWords, 1);
    expect(september28.photoCount, 1);
    expect(september28.status, DailyLessonStatus.noData);
  });

  test('uses capture time even when recognition completes after midnight', () {
    final overview = buildDailyLessonOverview(
      snapshots: [
        _snapshot(
          seed: 3,
          capturedAt: DateTime.utc(2026, 9, 27, 16, 59),
          words: const ['late result'],
          detectionCreatedAt: DateTime.utc(2026, 9, 27, 19),
        ),
      ],
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.month,
        anchorDay: DateTime.utc(2026, 9),
      ),
      boundary: boundary,
      now: DateTime.utc(2026, 9, 28),
      dailyTarget: 1,
    );

    expect(_node(overview, 27).validWords, 1);
    expect(_node(overview, 28).validWords, 0);
  });

  test('counts only unique valid words and explains excluded images', () {
    final capture = DateTime.utc(2026, 9, 27, 9);
    final overview = buildDailyLessonOverview(
      snapshots: [
        _snapshot(seed: 4, capturedAt: capture, words: const ['Apple']),
        _snapshot(seed: 5, capturedAt: capture, words: const [' apple  ']),
        _snapshot(
          seed: 6,
          capturedAt: capture,
          status: ScanRunStatus.pending,
        ),
        _snapshot(
          seed: 7,
          capturedAt: capture,
          status: ScanRunStatus.failed,
          errorCode: 'image_blurry',
        ),
      ],
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: DateTime.utc(2026, 9, 27),
      ),
      boundary: boundary,
      now: DateTime.utc(2026, 9, 27, 10),
      dailyTarget: 3,
    );

    final today = overview.todayNode;
    expect(today.validWords, 1);
    expect(today.missingWords, 2);
    expect(today.hasSystemPending, isTrue);
    expect(
      today.exclusionReasons[DailyLessonExclusionReason.duplicate],
      1,
    );
    expect(
      today.exclusionReasons[DailyLessonExclusionReason.pendingProcessing],
      1,
    );
    expect(
      today.exclusionReasons[DailyLessonExclusionReason.blurryImage],
      1,
    );
  });

  test('maps progress to in-progress, pending, failed and completed nodes', () {
    final selection = HomeLessonMapSelection(
      period: LessonMapPeriod.week,
      anchorDay: DateTime.utc(2026, 9, 24),
    );
    final snapshots = <PhotoNoteSnapshot>[];
    for (var index = 0; index < 5; index++) {
      snapshots.add(
        _snapshot(
          seed: 10 + index,
          capturedAt: DateTime.utc(2026, 9, 21 + index, 5),
          words: const ['one', 'two'],
        ),
      );
    }
    final overview = buildDailyLessonOverview(
      snapshots: snapshots,
      selection: selection,
      boundary: boundary,
      now: DateTime.utc(2026, 9, 25, 8),
      dailyTarget: 2,
      progressByDay: {
        DateTime.utc(2026, 9, 21): const DailyLessonProgress(correctCount: 1),
        DateTime.utc(2026, 9, 22): const DailyLessonProgress(
          correctCount: 2,
          completed: true,
          pendingSync: true,
        ),
        DateTime.utc(2026, 9, 23): const DailyLessonProgress(
          correctCount: 2,
          completed: true,
        ),
        DateTime.utc(2026, 9, 24): const DailyLessonProgress(
          correctCount: 2,
          completed: true,
          completionResultId: 'result-24',
          syncStatus: LessonCompletionSyncStatus.failed,
          lastSyncErrorCode: 'temporary_network',
        ),
      },
    );

    expect(_node(overview, 21).status, DailyLessonStatus.inProgress);
    expect(_node(overview, 22).status, DailyLessonStatus.pendingSync);
    expect(_node(overview, 23).status, DailyLessonStatus.completed);
    expect(_node(overview, 24).status, DailyLessonStatus.syncFailed);
    expect(_node(overview, 24).completionResultId, 'result-24');
    expect(_node(overview, 25).status, DailyLessonStatus.ready);
  });

  test('uses each immutable mission target and authoritative boundaries', () {
    final mission = DailyMission(
      userId: _userId,
      day: DateTime.utc(2026, 9, 28),
      timeZone: 'America/New_York',
      targetWords: 22,
      createdAt: DateTime.utc(2026, 9, 28, 4),
      startsAt: DateTime.utc(2026, 9, 28, 4),
      endsAt: DateTime.utc(2026, 9, 29, 4),
      nextDayEndsAt: DateTime.utc(2026, 9, 30, 4),
    );
    final missionBoundary = AccountDayBoundary(
      const Duration(hours: 7),
      missions: [mission],
    );
    final overview = buildDailyLessonOverview(
      snapshots: const [],
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: mission.day,
      ),
      boundary: missionBoundary,
      now: DateTime.utc(2026, 9, 28, 20),
      dailyTarget: 10,
    );

    expect(overview.today, mission.day);
    expect(overview.dailyTarget, 22);
    expect(overview.todayNode.targetWords, 22);
    expect(overview.usesDeviceTimeZoneFallback, isFalse);
    expect(missionBoundary.startUtc(mission.day), mission.startsAt);
  });

  test('keeps the real today task while browsing a historical period', () {
    final today = DateTime.utc(2026, 9, 27);
    final overview = buildDailyLessonOverview(
      snapshots: [
        _snapshot(
          seed: 40,
          capturedAt: DateTime.utc(2026, 9, 1, 9),
          words: const ['history'],
        ),
        _snapshot(
          seed: 41,
          capturedAt: DateTime.utc(2026, 9, 27, 9),
          words: const ['today'],
        ),
      ],
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: DateTime.utc(2026, 9, 1),
      ),
      boundary: const AccountDayBoundary(Duration.zero),
      now: today.add(const Duration(hours: 10)),
      dailyTarget: 2,
    );

    expect(overview.selection.contains(today), isFalse);
    expect(overview.nodes.any((node) => node.day == today), isFalse);
    expect(overview.todayNode.day, today);
    expect(overview.todayNode.validWords, 1);
    expect(overview.todayNode.photoCount, 1);
  });

  test('period navigation shifts week and month then returns to today', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final anchorSubscription = container.listen(
      homeLessonMapAnchorProvider,
      (_, __) {},
      fireImmediately: true,
    );
    final periodSubscription = container.listen(
      homeLessonMapPeriodProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(anchorSubscription.close);
    addTearDown(periodSubscription.close);
    final anchorNotifier = container.read(
      homeLessonMapAnchorProvider.notifier,
    );

    anchorNotifier.shift(
      HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: DateTime.utc(2026, 9, 27),
      ),
      -1,
    );
    expect(
      container.read(homeLessonMapAnchorProvider),
      DateTime.utc(2026, 9, 20),
    );

    anchorNotifier.shift(
      HomeLessonMapSelection(
        period: LessonMapPeriod.month,
        anchorDay: DateTime.utc(2026, 9, 27),
      ),
      1,
    );
    expect(
      container.read(homeLessonMapAnchorProvider),
      DateTime.utc(2026, 10),
    );

    container
        .read(homeLessonMapPeriodProvider.notifier)
        .setPeriod(LessonMapPeriod.month);
    expect(container.read(homeLessonMapPeriodProvider), LessonMapPeriod.month);
    expect(container.read(homeLessonMapAnchorProvider), isNull);
  });

  test('today task stays reactive while a historical period is open', () async {
    final repository = _ReactiveLibraryRepository();
    addTearDown(repository.dispose);
    final now = DateTime.utc(2026, 9, 27, 10);
    final container = ProviderContainer(
      overrides: [
        currentLibraryUserIdProvider.overrideWithValue(_userId),
        libraryRepositoryProvider.overrideWith((ref) async => repository),
        homeDailyTargetProvider.overrideWith((ref) async => 10),
        homeAccountDayBoundaryProvider.overrideWithValue(
          const AccountDayBoundary(Duration.zero),
        ),
        homeNowProvider.overrideWithValue(now),
        homeDayTickProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(container.dispose);
    final anchorSubscription = container.listen(
      homeLessonMapAnchorProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(anchorSubscription.close);
    container.read(homeLessonMapAnchorProvider.notifier).shift(
          HomeLessonMapSelection(
            period: LessonMapPeriod.week,
            anchorDay: DateTime.utc(2026, 9, 8),
          ),
          -1,
        );

    final updated = Completer<DailyLessonOverview>();
    final lessonSubscription = container.listen(
      homeDailyLessonProvider,
      (_, next) => next.whenData((overview) {
        if (overview.todayNode.validWords == 1 && !updated.isCompleted) {
          updated.complete(overview);
        }
      }),
      fireImmediately: true,
    );
    addTearDown(lessonSubscription.close);
    final initial = await container.read(homeDailyLessonProvider.future);
    expect(initial.selection.contains(initial.today), isFalse);
    expect(initial.todayNode.validWords, 0);

    repository.add(
      _snapshot(
        seed: 42,
        capturedAt: DateTime.utc(2026, 9, 27, 11),
        words: const ['fresh'],
      ),
    );

    final refreshed = await updated.future.timeout(const Duration(seconds: 2));
    expect(refreshed.todayNode.validWords, 1);
    expect(refreshed.nodes.any((node) => node.day == refreshed.today), isFalse);
  });

  test('provider emits an empty offline map instead of staying on loading',
      () async {
    final repository = _EmptyLibraryRepository();
    final now = DateTime.utc(2026, 9, 27, 10);
    final container = ProviderContainer(
      overrides: [
        currentLibraryUserIdProvider.overrideWithValue(_userId),
        libraryRepositoryProvider.overrideWith((ref) async => repository),
        homeDailyTargetProvider.overrideWith((ref) async => 10),
        homeAccountDayBoundaryProvider.overrideWithValue(boundary),
        homeNowProvider.overrideWithValue(now),
        homeDayTickProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      homeDailyLessonProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final overview = await container
        .read(homeDailyLessonProvider.future)
        .timeout(const Duration(seconds: 2));

    expect(overview.todayNode.status, DailyLessonStatus.noData);
    expect(overview.todayNode.validWords, 0);
    expect(repository.lastQuery?.userId, _userId);
    expect(repository.lastQuery?.capturedFromInclusive, isNotNull);
    expect(repository.lastQuery?.capturedToExclusive, isNotNull);
  });
}

DailyLessonNode _node(DailyLessonOverview overview, int day) =>
    overview.nodes.singleWhere((node) => node.day.day == day);

PhotoNoteSnapshot _snapshot({
  required int seed,
  required DateTime capturedAt,
  List<String> words = const [],
  ScanRunStatus status = ScanRunStatus.succeeded,
  String? errorCode,
  DateTime? detectionCreatedAt,
}) {
  final noteId = _uuid(seed * 10 + 1);
  final mediaId = _uuid(seed * 10 + 2);
  final scanId = _uuid(seed * 10 + 3);
  final createdAt = capturedAt.toUtc();
  final scan = ScanRun(
    id: scanId,
    userId: _userId,
    mediaAssetId: mediaId,
    requestId: 'request-$seed',
    provider: 'test',
    modelName: 'test-model',
    promptVersion: 'v1',
    responseSchemaVersion: 'v1',
    preprocessingVersion: 'v1',
    status: status,
    rawResponseJson:
        status == ScanRunStatus.succeeded ? {'words': words} : null,
    responseHashSha256: status == ScanRunStatus.succeeded ? _hash : null,
    errorCode: errorCode,
    startedAt: createdAt,
    completedAt: status == ScanRunStatus.pending
        ? null
        : (detectionCreatedAt ?? createdAt.add(const Duration(seconds: 1))),
  );
  final detections = <VocabDetection>[
    for (var index = 0; index < words.length; index++)
      VocabDetection(
        id: _uuid(seed * 100 + index + 1),
        scanRunId: scanId,
        wordRaw: words[index],
        wordNormalized: words[index],
        boundingBox: NormalizedBoundingBox(
          x: 0.05 + (index * 0.1),
          y: 0.1,
          width: 0.08,
          height: 0.1,
        ),
        displayOrder: index,
        createdAt: detectionCreatedAt ?? createdAt,
      ),
  ];
  return PhotoNoteSnapshot(
    photoNote: PhotoNote(
      id: noteId,
      userId: _userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Note $seed',
      templateId: 'default',
      createdAt: createdAt,
      updatedAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: _userId,
      contentHashSha256: _hash,
      displayRelativePath: 'media/$seed.jpg',
      mimeType: 'image/jpeg',
      width: 100,
      height: 100,
      orientation: 0,
      byteSizeDisplay: 10,
      preprocessingVersion: 'v1',
      captureSource: CaptureSource.camera,
      capturedAt: capturedAt.toUtc(),
      createdAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    primaryScanRun: scan,
    detections: detections,
    annotations: const [],
  );
}

String _uuid(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

const _userId = '00000000-0000-4000-8000-000000000001';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _EmptyLibraryRepository implements LibraryRepository {
  PhotoNoteQuery? lastQuery;

  @override
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query) {
    lastQuery = query;
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReactiveLibraryRepository implements LibraryRepository {
  final _changes = StreamController<int>.broadcast();
  final _snapshots = <String, PhotoNoteSnapshot>{};

  void add(PhotoNoteSnapshot snapshot) {
    _snapshots[snapshot.photoNote.id] = snapshot;
    _changes.add(_snapshots.length);
  }

  Future<void> dispose() => _changes.close();

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async =>
      _snapshots[photoNoteId];

  @override
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query) async* {
    yield _matching(query);
    await for (final _ in _changes.stream) {
      yield _matching(query);
    }
  }

  List<PhotoNote> _matching(PhotoNoteQuery query) => _snapshots.values
      .where((snapshot) {
        final capturedAt =
            snapshot.mediaAsset.capturedAt ?? snapshot.mediaAsset.createdAt;
        final from = query.capturedFromInclusive;
        final to = query.capturedToExclusive;
        return snapshot.photoNote.userId == query.userId &&
            (from == null || !capturedAt.isBefore(from)) &&
            (to == null || capturedAt.isBefore(to));
      })
      .map((snapshot) => snapshot.photoNote)
      .toList(growable: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
