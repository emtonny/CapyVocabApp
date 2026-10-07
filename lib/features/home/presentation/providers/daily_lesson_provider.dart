import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../library/domain/entities/library_enums.dart';
import '../../../library/domain/entities/photo_note.dart';
import '../../../library/domain/entities/photo_note_snapshot.dart';
import '../../../library/domain/entities/scan_models.dart';
import '../../../library/domain/repositories/library_repository.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../mini_games/domain/lesson_session.dart';
import '../../../mini_games/presentation/providers/lesson_session_provider.dart';
import '../../domain/daily_mission.dart';
import 'daily_mission_provider.dart';

enum LessonMapPeriod { week, month }

enum DailyLessonStatus {
  noData,
  ready,
  inProgress,
  pendingSync,
  syncFailed,
  completed,
  expired,
}

enum DailyLessonExclusionReason {
  duplicate,
  blurryImage,
  notRecognized,
  wrongLearningLanguage,
  pendingProcessing,
}

class AccountDayBoundary {
  const AccountDayBoundary(
    this.utcOffset, {
    this.missions = const [],
  });

  final Duration utcOffset;
  final List<DailyMission> missions;

  DateTime dayFor(DateTime instant) {
    final utc = instant.toUtc();
    for (final mission in missions) {
      if (mission.contains(utc)) return mission.day;
    }
    final shifted = instant.toUtc().add(utcOffset);
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }

  DateTime startUtc(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    for (final mission in missions) {
      if (mission.day == normalized) return mission.startsAt;
    }
    return normalized.subtract(utcOffset);
  }

  DailyMission? missionForDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    for (final mission in missions) {
      if (mission.day == normalized) return mission;
    }
    return null;
  }
}

class HomeLessonMapSelection {
  const HomeLessonMapSelection({
    required this.period,
    required this.anchorDay,
  });

  final LessonMapPeriod period;
  final DateTime anchorDay;

  DateTime get startDay {
    if (period == LessonMapPeriod.month) {
      return DateTime.utc(anchorDay.year, anchorDay.month);
    }
    return anchorDay.subtract(Duration(days: anchorDay.weekday - 1));
  }

  DateTime get endDayExclusive {
    if (period == LessonMapPeriod.month) {
      return DateTime.utc(anchorDay.year, anchorDay.month + 1);
    }
    return startDay.add(const Duration(days: 7));
  }

  bool contains(DateTime day) =>
      !day.isBefore(startDay) && day.isBefore(endDayExclusive);

  HomeLessonMapSelection copyWith({
    LessonMapPeriod? period,
    DateTime? anchorDay,
  }) {
    return HomeLessonMapSelection(
      period: period ?? this.period,
      anchorDay: anchorDay ?? this.anchorDay,
    );
  }
}

class DailyLessonProgress {
  const DailyLessonProgress({
    required this.correctCount,
    this.completed = false,
    this.completionResultId,
    LessonCompletionSyncStatus? syncStatus,
    bool pendingSync = false,
    this.lastSyncErrorCode,
  }) : syncStatus = syncStatus ??
            (pendingSync ? LessonCompletionSyncStatus.pending : null);

  final int correctCount;
  final bool completed;
  final String? completionResultId;
  final LessonCompletionSyncStatus? syncStatus;
  final String? lastSyncErrorCode;

  bool get pendingSync => {
        LessonCompletionSyncStatus.pending,
        LessonCompletionSyncStatus.syncing,
      }.contains(syncStatus);

  bool get syncFailed => syncStatus == LessonCompletionSyncStatus.failed;
}

class DailyLessonNode {
  const DailyLessonNode({
    required this.day,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.targetWords,
    required this.validWords,
    required this.correctWords,
    required this.photoCount,
    required this.projectedYuzu,
    required this.exclusionReasons,
    required this.photoNoteIds,
    required this.hasSystemPending,
    this.completionResultId,
    this.lastSyncErrorCode,
  });

  final DateTime day;
  final DateTime startsAt;
  final DateTime endsAt;
  final DailyLessonStatus status;
  final int targetWords;
  final int validWords;
  final int correctWords;
  final int photoCount;
  final int projectedYuzu;
  final Map<DailyLessonExclusionReason, int> exclusionReasons;
  final List<String> photoNoteIds;
  final bool hasSystemPending;
  final String? completionResultId;
  final String? lastSyncErrorCode;

  int get missingWords => (targetWords - validWords).clamp(0, targetWords);

  bool get canRetake => exclusionReasons.keys.any(
        (reason) => switch (reason) {
          DailyLessonExclusionReason.blurryImage ||
          DailyLessonExclusionReason.notRecognized ||
          DailyLessonExclusionReason.wrongLearningLanguage =>
            true,
          DailyLessonExclusionReason.duplicate ||
          DailyLessonExclusionReason.pendingProcessing =>
            false,
        },
      );
}

class DailyLessonOverview {
  const DailyLessonOverview({
    required this.today,
    required this.selection,
    required this.nodes,
    required this.todayNode,
    required this.dailyTarget,
    required this.usesDeviceTimeZoneFallback,
  });

  final DateTime today;
  final HomeLessonMapSelection selection;
  final List<DailyLessonNode> nodes;
  final DailyLessonNode todayNode;
  final int dailyTarget;
  final bool usesDeviceTimeZoneFallback;
}

abstract interface class HomeDailyTargetCache {
  Future<int?> read(String userId);

  Future<void> write(String userId, int value);
}

class SharedPreferencesHomeDailyTargetCache implements HomeDailyTargetCache {
  static const _keyPrefix = 'home_daily_target_v1_';

  @override
  Future<int?> read(String userId) async {
    final value =
        (await SharedPreferences.getInstance()).getInt('$_keyPrefix$userId');
    return value != null && value > 0 ? value : null;
  }

  @override
  Future<void> write(String userId, int value) async {
    if (value <= 0) return;
    await (await SharedPreferences.getInstance())
        .setInt('$_keyPrefix$userId', value);
  }
}

typedef HomeDailyTargetLoader = Future<int> Function();

final homeNowProvider = Provider<DateTime>((_) => DateTime.now().toUtc());

/// Temporary fallback until an account timezone field exists in user settings.
final homeAccountDayBoundaryProvider = Provider<AccountDayBoundary>(
  (_) => AccountDayBoundary(DateTime.now().timeZoneOffset),
);

// Keep this clock alive for the ProviderScope lifetime. Making both this clock
// and its only consumer auto-dispose can repeatedly recreate an AsyncLoading
// clock while the daily stream is being recomputed, leaving Home on a spinner.
final homeDayTickProvider = StreamProvider<DateTime>((ref) {
  final boundary = ref.watch(homeAccountDayBoundaryProvider);
  late final StreamController<DateTime> controller;
  Timer? timer;

  void scheduleNextDay() {
    final now = DateTime.now().toUtc();
    if (!controller.isClosed) controller.add(now);
    final today = boundary.dayFor(now);
    final nextMidnight = boundary.startUtc(
      today.add(const Duration(days: 1)),
    );
    final delay = nextMidnight.difference(now);
    timer = Timer(delay.isNegative ? Duration.zero : delay, scheduleNextDay);
  }

  controller = StreamController<DateTime>(
    onListen: scheduleNextDay,
    onCancel: () => timer?.cancel(),
  );
  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

final homeDailyTargetCacheProvider = Provider<HomeDailyTargetCache>(
  (_) => SharedPreferencesHomeDailyTargetCache(),
);

final homeDailyTargetLoaderProvider = Provider<HomeDailyTargetLoader>((ref) {
  final repository = ref.watch(onboardingRepositoryProvider);
  return () async => (await repository.loadDraft()).dailyTargetWords ?? 10;
});

final homeDailyTargetProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) return 10;
  final cache = ref.watch(homeDailyTargetCacheProvider);
  int? cached;
  try {
    cached = await cache.read(userId);
  } catch (_) {
    // A damaged preference must not prevent the daily map from opening.
  }
  try {
    final target = await ref.watch(homeDailyTargetLoaderProvider)();
    if (target <= 0) throw const FormatException('invalid daily target');
    try {
      await cache.write(userId, target);
    } catch (_) {
      // Fresh data remains usable if the local cache cannot be written.
    }
    return target;
  } catch (_) {
    return cached ?? 10;
  }
});

class HomeLessonMapPeriodNotifier extends AutoDisposeNotifier<LessonMapPeriod> {
  @override
  LessonMapPeriod build() => LessonMapPeriod.week;

  void setPeriod(LessonMapPeriod period) {
    state = period;
    ref.read(homeLessonMapAnchorProvider.notifier).goToday();
  }
}

class HomeLessonMapAnchorNotifier extends AutoDisposeNotifier<DateTime?> {
  @override
  DateTime? build() => null;

  void shift(HomeLessonMapSelection selection, int direction) {
    if (direction != -1 && direction != 1) {
      throw ArgumentError.value(direction, 'direction', 'must be -1 or 1');
    }
    final anchor = selection.period == LessonMapPeriod.month
        ? DateTime.utc(
            selection.anchorDay.year,
            selection.anchorDay.month + direction,
          )
        : selection.anchorDay.add(Duration(days: 7 * direction));
    state = anchor;
  }

  void goToday() => state = null;
}

final homeLessonMapAnchorProvider =
    NotifierProvider.autoDispose<HomeLessonMapAnchorNotifier, DateTime?>(
  HomeLessonMapAnchorNotifier.new,
);

final homeLessonMapPeriodProvider =
    NotifierProvider.autoDispose<HomeLessonMapPeriodNotifier, LessonMapPeriod>(
  HomeLessonMapPeriodNotifier.new,
);

final homeDailyLessonProvider =
    StreamProvider.autoDispose<DailyLessonOverview>((ref) {
  final userId = ref.watch(currentLibraryUserIdProvider);
  final fallbackBoundary = ref.watch(homeAccountDayBoundaryProvider);
  final DateTime now = ref.watch(homeDayTickProvider).asData?.value ??
      ref.watch(homeNowProvider);
  final period = ref.watch(homeLessonMapPeriodProvider);
  final selectedAnchor = ref.watch(homeLessonMapAnchorProvider);
  final fallbackTarget = ref.watch(homeDailyTargetProvider).valueOrNull ?? 10;
  final publishedMission = ref.watch(currentDailyMissionProvider);
  final currentMission =
      publishedMission?.userId == userId ? publishedMission : null;
  final boundary = AccountDayBoundary(
    fallbackBoundary.utcOffset,
    missions: [if (currentMission != null) currentMission],
  );
  final today = boundary.dayFor(now);
  final selection = HomeLessonMapSelection(
    period: period,
    anchorDay: selectedAnchor ?? today,
  );
  final target = currentMission?.targetWords ?? fallbackTarget;

  List<LessonDayProgress> localProgress = const [];
  if (userId != null) {
    final from =
        selection.startDay.isBefore(today) ? selection.startDay : today;
    final selectionEnd = selection.endDayExclusive;
    final todayEnd = today.add(const Duration(days: 1));
    final to = selectionEnd.isAfter(todayEnd) ? selectionEnd : todayEnd;
    localProgress = ref
            .watch(
              lessonDayProgressProvider((
                userId: userId,
                fromInclusive: from,
                toExclusive: to,
              )),
            )
            .valueOrNull ??
        const [];
  }
  final progressByDay = <DateTime, DailyLessonProgress>{
    for (final progress in localProgress)
      progress.missionDate: DailyLessonProgress(
        correctCount: progress.completedItems,
        completed: progress.isCompleted,
        completionResultId: progress.completionResultId,
        syncStatus: progress.syncStatus,
        lastSyncErrorCode: progress.lastSyncErrorCode,
      ),
  };

  if (userId == null) {
    return Stream.value(
      buildDailyLessonOverview(
        snapshots: const [],
        selection: selection,
        boundary: boundary,
        now: now,
        dailyTarget: target,
        progressByDay: progressByDay,
      ),
    );
  }

  final repository = ref.watch(libraryRepositoryProvider);
  final Stream<DailyLessonOverview> repositoryStream =
      repository.when<Stream<DailyLessonOverview>>(
    loading: () => const Stream<DailyLessonOverview>.empty(),
    error: (error, stackTrace) =>
        Stream<DailyLessonOverview>.error(error, stackTrace),
    data: (repository) => Stream.value(boundary).asyncExpand(
      (resolvedBoundary) => _watchDailyLessonOverview(
        repository: repository,
        userId: userId,
        selection: selection,
        boundary: resolvedBoundary,
        now: now,
        dailyTarget: target,
        progressByDay: progressByDay,
      ),
    ),
  );

  if (currentMission == null) return repositoryStream;
  final cache = ref.watch(dailyMissionCacheProvider);
  return cache.when(
    loading: () => repositoryStream,
    error: (_, __) => repositoryStream,
    data: (cache) => Stream.fromFuture(
      cache
          .list(
            userId: userId,
            fromInclusive: selection.startDay,
            toExclusive: selection.endDayExclusive,
          )
          .then(
            (missions) => AccountDayBoundary(
              fallbackBoundary.utcOffset,
              missions: [
                currentMission,
                ...missions
                    .where((mission) => mission.day != currentMission.day),
              ],
            ),
            onError: (_) => boundary,
          ),
    ).asyncExpand(
      (resolvedBoundary) => repository.when<Stream<DailyLessonOverview>>(
        loading: () => const Stream<DailyLessonOverview>.empty(),
        error: (error, stackTrace) =>
            Stream<DailyLessonOverview>.error(error, stackTrace),
        data: (repository) => _watchDailyLessonOverview(
          repository: repository,
          userId: userId,
          selection: selection,
          boundary: resolvedBoundary,
          now: now,
          dailyTarget: target,
          progressByDay: progressByDay,
        ),
      ),
    ),
  );
});

Stream<DailyLessonOverview> _watchDailyLessonOverview({
  required LibraryRepository repository,
  required String userId,
  required HomeLessonMapSelection selection,
  required AccountDayBoundary boundary,
  required DateTime now,
  required int dailyTarget,
  required Map<DateTime, DailyLessonProgress> progressByDay,
}) {
  final today = boundary.dayFor(now);
  final selectionQuery = PhotoNoteQuery(
    userId: userId,
    capturedFromInclusive: boundary.startUtc(selection.startDay),
    capturedToExclusive: boundary.startUtc(selection.endDayExclusive),
    limit: 500,
  );
  final selectionNotes = repository.watchPhotoNotes(selectionQuery);
  final notes = selection.contains(today)
      ? selectionNotes
      : _combinePhotoNoteStreams(
          selectionNotes,
          repository.watchPhotoNotes(
            PhotoNoteQuery(
              userId: userId,
              capturedFromInclusive: boundary.startUtc(today),
              capturedToExclusive:
                  boundary.startUtc(today.add(const Duration(days: 1))),
              limit: 500,
            ),
          ),
        );
  return notes.asyncMap((allNotes) async {
    final snapshots = await Future.wait(
      allNotes.map(
        (note) => repository.getPhotoNoteSnapshot(
          userId: userId,
          photoNoteId: note.id,
        ),
      ),
    );
    return buildDailyLessonOverview(
      snapshots: snapshots.whereType<PhotoNoteSnapshot>(),
      selection: selection,
      boundary: boundary,
      now: now,
      dailyTarget: dailyTarget,
      progressByDay: progressByDay,
    );
  });
}

Stream<List<PhotoNote>> _combinePhotoNoteStreams(
  Stream<List<PhotoNote>> selectionNotes,
  Stream<List<PhotoNote>> todayNotes,
) {
  late StreamController<List<PhotoNote>> controller;
  late StreamSubscription<List<PhotoNote>> selectionSubscription;
  late StreamSubscription<List<PhotoNote>> todaySubscription;
  List<PhotoNote>? latestSelection;
  List<PhotoNote>? latestToday;
  var completedStreams = 0;

  void emitWhenReady() {
    if (latestSelection == null || latestToday == null) return;
    controller.add(
      List.unmodifiable([
        ...latestSelection!,
        ...latestToday!,
      ]),
    );
  }

  void closeWhenDone() {
    completedStreams++;
    if (completedStreams == 2) unawaited(controller.close());
  }

  controller = StreamController<List<PhotoNote>>(
    onListen: () {
      selectionSubscription = selectionNotes.listen(
        (notes) {
          latestSelection = notes;
          emitWhenReady();
        },
        onError: controller.addError,
        onDone: closeWhenDone,
      );
      todaySubscription = todayNotes.listen(
        (notes) {
          latestToday = notes;
          emitWhenReady();
        },
        onError: controller.addError,
        onDone: closeWhenDone,
      );
    },
    onPause: () {
      selectionSubscription.pause();
      todaySubscription.pause();
    },
    onResume: () {
      selectionSubscription.resume();
      todaySubscription.resume();
    },
    onCancel: () async {
      await Future.wait([
        selectionSubscription.cancel(),
        todaySubscription.cancel(),
      ]);
    },
  );
  return controller.stream;
}

DailyLessonOverview buildDailyLessonOverview({
  required Iterable<PhotoNoteSnapshot> snapshots,
  required HomeLessonMapSelection selection,
  required AccountDayBoundary boundary,
  required DateTime now,
  required int dailyTarget,
  Map<DateTime, DailyLessonProgress> progressByDay = const {},
}) {
  if (dailyTarget <= 0) {
    throw ArgumentError.value(dailyTarget, 'dailyTarget', 'must be positive');
  }
  final today = boundary.dayFor(now);
  final grouped = <DateTime, List<PhotoNoteSnapshot>>{};
  for (final snapshot in snapshots) {
    final capturedAt =
        snapshot.mediaAsset.capturedAt ?? snapshot.mediaAsset.createdAt;
    final day = boundary.dayFor(capturedAt);
    if (!selection.contains(day) && !_sameDay(day, today)) {
      continue;
    }
    grouped.putIfAbsent(day, () => []).add(snapshot);
  }

  final nodes = <DailyLessonNode>[];
  for (var day = selection.startDay;
      day.isBefore(selection.endDayExclusive);
      day = day.add(const Duration(days: 1))) {
    final dayKey = DateTime.utc(day.year, day.month, day.day);
    final target = boundary.missionForDay(dayKey)?.targetWords ?? dailyTarget;
    nodes.add(
      _buildNode(
        day: dayKey,
        startsAt: boundary.startUtc(dayKey),
        endsAt: boundary.startUtc(dayKey.add(const Duration(days: 1))),
        today: today,
        dailyTarget: target,
        snapshots: grouped[dayKey] ?? const [],
        progress: progressByDay[dayKey],
      ),
    );
  }
  final todayTarget = boundary.missionForDay(today)?.targetWords ?? dailyTarget;
  final matchingTodayNodes =
      nodes.where((node) => _sameDay(node.day, today)).toList();
  final todayNode = matchingTodayNodes.isNotEmpty
      ? matchingTodayNodes.first
      : _buildNode(
          day: today,
          startsAt: boundary.startUtc(today),
          endsAt: boundary.startUtc(today.add(const Duration(days: 1))),
          today: today,
          dailyTarget: todayTarget,
          snapshots: grouped[today] ?? const [],
          progress: progressByDay[today],
        );
  return DailyLessonOverview(
    today: today,
    selection: selection,
    nodes: List.unmodifiable(nodes),
    todayNode: todayNode,
    dailyTarget: todayTarget,
    usesDeviceTimeZoneFallback: boundary.missionForDay(today) == null,
  );
}

DailyLessonNode _buildNode({
  required DateTime day,
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime today,
  required int dailyTarget,
  required List<PhotoNoteSnapshot> snapshots,
  DailyLessonProgress? progress,
}) {
  final validWords = <String>{};
  final reasons = <DailyLessonExclusionReason, int>{};
  final photoNoteIds = <String>[];
  var hasPending = false;

  void addReason(DailyLessonExclusionReason reason, [int amount = 1]) {
    reasons.update(reason, (value) => value + amount, ifAbsent: () => amount);
  }

  for (final snapshot in snapshots) {
    photoNoteIds.add(snapshot.photoNote.id);
    final run = snapshot.primaryScanRun;
    if (run == null || run.status == ScanRunStatus.pending) {
      hasPending = true;
      addReason(DailyLessonExclusionReason.pendingProcessing);
      continue;
    }
    if (run.status != ScanRunStatus.succeeded) {
      addReason(_reasonForScanError(run.errorCode));
      continue;
    }
    if (snapshot.detections.isEmpty) {
      addReason(DailyLessonExclusionReason.notRecognized);
      continue;
    }

    final annotations = snapshot.annotationsByDetectionId;
    for (final detection in snapshot.detections) {
      final revisions = annotations[detection.id] ?? const [];
      VocabAnnotation? latest;
      for (final item in revisions) {
        if (item.deletedAt == null &&
            (latest == null || item.revision > latest.revision)) {
          latest = item;
        }
      }
      if (latest?.qualityStatus == AnnotationQualityStatus.rejected) {
        addReason(DailyLessonExclusionReason.notRecognized);
        continue;
      }
      if ((latest?.correctedBoundingBox ?? detection.boundingBox) == null) {
        addReason(DailyLessonExclusionReason.notRecognized);
        continue;
      }
      final word = _normalizeWord(
        latest?.correctedWord ?? detection.wordNormalized,
      );
      if (word.isEmpty) {
        addReason(DailyLessonExclusionReason.notRecognized);
      } else if (!validWords.add(word)) {
        addReason(DailyLessonExclusionReason.duplicate);
      }
    }
  }

  final status = _resolveStatus(
    day: day,
    today: today,
    validWords: validWords.length,
    targetWords: dailyTarget,
    hasPending: hasPending,
    progress: progress,
  );
  return DailyLessonNode(
    day: day,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status,
    targetWords: dailyTarget,
    validWords: validWords.length,
    correctWords: progress?.correctCount.clamp(0, validWords.length) ?? 0,
    photoCount: snapshots.length,
    projectedYuzu: _projectedYuzu(validWords.length, dailyTarget),
    exclusionReasons: Map.unmodifiable(reasons),
    photoNoteIds: List.unmodifiable(photoNoteIds),
    hasSystemPending: hasPending,
    completionResultId: progress?.completionResultId,
    lastSyncErrorCode: progress?.lastSyncErrorCode,
  );
}

DailyLessonStatus _resolveStatus({
  required DateTime day,
  required DateTime today,
  required int validWords,
  required int targetWords,
  required bool hasPending,
  DailyLessonProgress? progress,
}) {
  if (progress?.syncFailed == true) return DailyLessonStatus.syncFailed;
  if (progress?.pendingSync == true) return DailyLessonStatus.pendingSync;
  if (progress?.completed == true) return DailyLessonStatus.completed;
  if ((progress?.correctCount ?? 0) > 0) return DailyLessonStatus.inProgress;
  if (day.isBefore(today) && !hasPending) return DailyLessonStatus.expired;
  if (validWords < targetWords) return DailyLessonStatus.noData;
  return DailyLessonStatus.ready;
}

DailyLessonExclusionReason _reasonForScanError(String? code) {
  final normalized = (code ?? '').toLowerCase();
  if (normalized.contains('blur')) {
    return DailyLessonExclusionReason.blurryImage;
  }
  if (normalized.contains('language') || normalized.contains('locale')) {
    return DailyLessonExclusionReason.wrongLearningLanguage;
  }
  return DailyLessonExclusionReason.notRecognized;
}

String _normalizeWord(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int _projectedYuzu(int validWords, int targetWords) {
  if (validWords < targetWords) return 0;
  if (validWords >= targetWords * 2) return 150;
  if (validWords * 2 >= targetWords * 3) return 130;
  return 100;
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
