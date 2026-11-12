import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/data/local/library_database_factory.dart';
import '../../data/local/sqlite_lesson_session_store.dart';
import '../../domain/lesson_session.dart';

typedef DailyLessonSessionKey = ({String userId, DateTime missionDate});
typedef LessonCompletionKey = ({String userId, String sessionId});
typedef LessonProgressRangeKey = ({
  String userId,
  DateTime fromInclusive,
  DateTime toExclusive,
});

final lessonSessionStoreProvider =
    FutureProvider<SqliteLessonSessionStore>((ref) async {
  return SqliteLessonSessionStore(await openDefaultLibraryDatabase());
});

final dailyLessonSessionProvider = FutureProvider.autoDispose
    .family<LessonSession?, DailyLessonSessionKey>((ref, key) async {
  final store = await ref.watch(lessonSessionStoreProvider.future);
  return store.getDaily(
    userId: key.userId,
    missionDate: key.missionDate,
  );
});

final lessonCompletionProvider = StreamProvider.autoDispose
    .family<LessonCompletionResult?, LessonCompletionKey>((ref, key) async* {
  final store = await ref.watch(lessonSessionStoreProvider.future);
  await for (final _ in store.watchChanges(key.userId)) {
    yield await store.getCompletion(
      userId: key.userId,
      sessionId: key.sessionId,
    );
  }
});

final lessonDayProgressProvider = StreamProvider.autoDispose
    .family<List<LessonDayProgress>, LessonProgressRangeKey>(
  (ref, key) async* {
    final store = await ref.watch(lessonSessionStoreProvider.future);
    await for (final _ in store.watchChanges(key.userId)) {
      yield await store.listDailyProgress(
        userId: key.userId,
        fromInclusive: key.fromInclusive,
        toExclusive: key.toExclusive,
      );
    }
  },
);

final lessonPendingYuzuProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) async* {
  final store = await ref.watch(lessonSessionStoreProvider.future);
  await for (final _ in store.watchChanges(userId)) {
    yield await store.pendingYuzuEstimate(userId);
  }
});
