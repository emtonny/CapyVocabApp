import 'package:flutter/foundation.dart';

import '../data/local/sqlite_lesson_session_store.dart';
import '../domain/lesson_game.dart';
import '../domain/lesson_session.dart';
import 'lesson_question_builder.dart';
import 'lesson_source_builder.dart';

enum LessonFlowPhase {
  loading,
  ready,
  answering,
  submitting,
  feedback,
  completed,
  empty,
  error,
  paused,
  blocked,
  abandoned,
  expired,
}

sealed class LessonStartRequest {
  const LessonStartRequest();

  String get userId;
  DateTime get now;
}

final class DailyLessonStartRequest extends LessonStartRequest {
  DailyLessonStartRequest({
    required this.userId,
    required this.missionDate,
    required this.photoNoteIds,
    required this.targetWords,
    required this.ruleVersion,
    required this.startsAt,
    required this.endsAt,
    required this.nextDayEndsAt,
    required this.now,
  }) {
    if (userId.trim().isEmpty || ruleVersion.trim().isEmpty) {
      throw ArgumentError('userId and ruleVersion must not be blank');
    }
    if (targetWords <= 0) {
      throw ArgumentError.value(targetWords, 'targetWords', 'must be positive');
    }
    for (final entry in {
      'missionDate': missionDate,
      'startsAt': startsAt,
      'endsAt': endsAt,
      'nextDayEndsAt': nextDayEndsAt,
      'now': now,
    }.entries) {
      if (!entry.value.isUtc) {
        throw ArgumentError.value(entry.value, entry.key, 'must be UTC');
      }
    }
    if (missionDate !=
        DateTime.utc(missionDate.year, missionDate.month, missionDate.day)) {
      throw ArgumentError.value(
        missionDate,
        'missionDate',
        'must be a UTC calendar date',
      );
    }
    if (!startsAt.isBefore(endsAt) || !endsAt.isBefore(nextDayEndsAt)) {
      throw ArgumentError('Daily lesson boundaries must be ordered');
    }
  }

  @override
  final String userId;
  final DateTime missionDate;
  final List<String> photoNoteIds;
  final int targetWords;
  final String ruleVersion;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime nextDayEndsAt;
  @override
  final DateTime now;
}

final class ReviewLessonStartRequest extends LessonStartRequest {
  ReviewLessonStartRequest({
    required this.userId,
    required this.photoNoteIds,
    required this.preference,
    required this.now,
    this.maxItems = 100,
    this.ruleVersion = 'h3-rules-v1',
  }) {
    if (userId.trim().isEmpty || photoNoteIds.isEmpty) {
      throw ArgumentError(
          'Review requires an owner and at least one Photo Note');
    }
    if (!now.isUtc) {
      throw ArgumentError.value(now, 'now', 'must be UTC');
    }
    if (maxItems <= 0 || maxItems > 500) {
      throw ArgumentError.value(maxItems, 'maxItems', 'must be 1 to 500');
    }
  }

  @override
  final String userId;
  final List<String> photoNoteIds;
  final LessonGamePreference preference;
  @override
  final DateTime now;
  final int maxItems;
  final String ruleVersion;
}

final class RewardedReplayLessonStartRequest extends LessonStartRequest {
  RewardedReplayLessonStartRequest({
    required this.userId,
    required this.missionDate,
    required this.targetWords,
    required this.now,
  }) {
    if (userId.trim().isEmpty || targetWords <= 0) {
      throw ArgumentError('Replay owner and target must be valid');
    }
    for (final entry in {
      'missionDate': missionDate,
      'now': now,
    }.entries) {
      if (!entry.value.isUtc) {
        throw ArgumentError.value(entry.value, entry.key, 'must be UTC');
      }
    }
    if (missionDate !=
        DateTime.utc(missionDate.year, missionDate.month, missionDate.day)) {
      throw ArgumentError.value(
        missionDate,
        'missionDate',
        'must be a UTC calendar date',
      );
    }
  }

  @override
  final String userId;
  final DateTime missionDate;
  final int targetWords;
  @override
  final DateTime now;
}

final class LessonFlowState {
  const LessonFlowState({
    required this.phase,
    this.session,
    this.question,
    this.feedbackAttempt,
    this.source,
    this.error,
  });

  const LessonFlowState.loading() : this(phase: LessonFlowPhase.loading);

  final LessonFlowPhase phase;
  final LessonSession? session;
  final BuiltLessonQuestion? question;
  final LessonGradedAttempt? feedbackAttempt;
  final LessonSourceBuildResult? source;
  final Object? error;
}

typedef LessonIdFactory = String Function();
typedef LessonNow = DateTime Function();

final class LessonSessionController extends ChangeNotifier {
  LessonSessionController({
    required SqliteLessonSessionStore store,
    required LessonSourceLoader sourceLoader,
    required LessonIdFactory sessionIdFactory,
    required LessonIdFactory questionIdFactory,
    required LessonIdFactory attemptIdFactory,
    LessonNow? now,
    LessonQuestionBuilder questionBuilder = const LessonQuestionBuilder(),
  })  : _store = store,
        _sourceLoader = sourceLoader,
        _sessionIdFactory = sessionIdFactory,
        _questionIdFactory = questionIdFactory,
        _attemptIdFactory = attemptIdFactory,
        _now = now ?? _systemUtcNow,
        _questionBuilder = questionBuilder;

  final SqliteLessonSessionStore _store;
  final LessonSourceLoader _sourceLoader;
  final LessonIdFactory _sessionIdFactory;
  final LessonIdFactory _questionIdFactory;
  final LessonIdFactory _attemptIdFactory;
  final LessonNow _now;
  final LessonQuestionBuilder _questionBuilder;

  LessonFlowState _state = const LessonFlowState.loading();
  BuiltLessonQuestion? _nextQuestion;
  LessonGamePreference _gamePreference = LessonGamePreference.mixed;
  DateTime? _activeRewardWindowEndsAt;

  LessonFlowState get state => _state;

  Future<void> openDaily(DailyLessonStartRequest request) async {
    _activeRewardWindowEndsAt = null;
    _gamePreference = LessonGamePreference.mixed;
    _set(const LessonFlowState.loading());
    try {
      var session = await _store.getDaily(
        userId: request.userId,
        missionDate: request.missionDate,
      );
      LessonSourceBuildResult? source;
      if (session == null) {
        source = await _sourceLoader.load(
          userId: request.userId,
          photoNoteIds: request.photoNoteIds,
          maxItems: request.targetWords,
        );
        if (source.items.length < request.targetWords) {
          _set(LessonFlowState(
            phase: LessonFlowPhase.empty,
            source: source,
          ));
          return;
        }
        session = await _store.createOrLoadDaily(
          LessonSession.daily(
            id: _sessionIdFactory(),
            userId: request.userId,
            missionDate: request.missionDate,
            items: source.items,
            sourceRevisionHash: source.sourceRevisionHash,
            ruleVersion: request.ruleVersion,
            startsAt: request.startsAt,
            endsAt: request.endsAt,
            nextDayEndsAt: request.nextDayEndsAt,
            startedAt: request.now,
          ),
        );
      }

      if (!request.now.isBefore(session.nextDayEndsAt) &&
          _canExpire(session.status)) {
        session = await _store.expire(
          userId: session.userId,
          sessionId: session.id,
          now: request.now,
        );
      }
      if (_isTerminal(session.status)) {
        _set(_terminalState(session, source: source));
        return;
      }
      if (session.status == LessonSessionStatus.blocked) {
        _set(LessonFlowState(
          phase: LessonFlowPhase.blocked,
          session: session,
          source: source,
        ));
        return;
      }
      if (!await _sourceLoader.isSessionSourceAvailable(session)) {
        if (session.status != LessonSessionStatus.blocked) {
          session = await _store.block(
            userId: session.userId,
            sessionId: session.id,
            now: request.now,
          );
        }
        _set(LessonFlowState(
          phase: LessonFlowPhase.blocked,
          session: session,
          source: source,
        ));
        return;
      }
      if (session.status == LessonSessionStatus.paused) {
        session = await _store.resume(
          userId: session.userId,
          sessionId: session.id,
          now: request.now,
        );
      }
      _set(LessonFlowState(
        phase: LessonFlowPhase.ready,
        session: session,
        source: source,
      ));
      await _showCurrentOrNextQuestion(session, source: source);
    } catch (error) {
      _set(LessonFlowState(phase: LessonFlowPhase.error, error: error));
    }
  }

  Future<void> openReview(ReviewLessonStartRequest request) async {
    _activeRewardWindowEndsAt = null;
    _gamePreference = request.preference;
    _set(const LessonFlowState.loading());
    try {
      final source = await _sourceLoader.load(
        userId: request.userId,
        photoNoteIds: request.photoNoteIds,
        maxItems: request.maxItems,
      );
      if (source.items.isEmpty) {
        _set(LessonFlowState(
          phase: LessonFlowPhase.empty,
          source: source,
        ));
        return;
      }
      final session = LessonSession.review(
        id: _sessionIdFactory(),
        userId: request.userId,
        items: source.items,
        sourceRevisionHash: source.sourceRevisionHash,
        ruleVersion: request.ruleVersion,
        startedAt: request.now,
      );
      await _store.create(session);
      _set(LessonFlowState(
        phase: LessonFlowPhase.ready,
        session: session,
        source: source,
      ));
      await _showCurrentOrNextQuestion(session, source: source);
    } catch (error) {
      _set(LessonFlowState(phase: LessonFlowPhase.error, error: error));
    }
  }

  Future<void> openRewardedReplay(
    RewardedReplayLessonStartRequest request,
  ) async {
    _gamePreference = LessonGamePreference.mixed;
    _activeRewardWindowEndsAt = null;
    _set(const LessonFlowState.loading());
    try {
      final original = await _store.getDaily(
        userId: request.userId,
        missionDate: request.missionDate,
      );
      if (original == null ||
          original.status != LessonSessionStatus.completed ||
          !original.mastery.isComplete) {
        throw StateError('Bài gốc chưa hoàn thành để mở lượt chơi lại.');
      }
      final rewardedReplay = await _store.getRewardedReplay(
        userId: request.userId,
        missionDate: request.missionDate,
      );
      final rewardWindowOpen = request.now.isBefore(original.nextDayEndsAt);
      LessonSession replay;
      if (rewardedReplay == null && rewardWindowOpen) {
        _activeRewardWindowEndsAt = original.nextDayEndsAt;
        replay = await _store.createOrLoadRewardedReplay(
          session: LessonSession.review(
            id: '${original.id}:rewarded-replay',
            userId: original.userId,
            items: original.items,
            sourceRevisionHash: original.sourceRevisionHash,
            ruleVersion: original.ruleVersion,
            startedAt: request.now,
          ),
          missionDate: request.missionDate,
        );
      } else if (rewardedReplay != null &&
          !_isTerminal(rewardedReplay.status) &&
          rewardWindowOpen) {
        _activeRewardWindowEndsAt = original.nextDayEndsAt;
        replay = rewardedReplay;
      } else {
        replay = LessonSession.review(
          id: _sessionIdFactory(),
          userId: original.userId,
          items: original.items,
          sourceRevisionHash: original.sourceRevisionHash,
          ruleVersion: original.ruleVersion,
          startedAt: request.now,
        );
        await _store.create(replay);
      }
      if (!await _sourceLoader.isSessionSourceAvailable(replay)) {
        replay = await _store.block(
          userId: replay.userId,
          sessionId: replay.id,
          now: request.now,
        );
        _set(LessonFlowState(
          phase: LessonFlowPhase.blocked,
          session: replay,
        ));
        return;
      }
      if (replay.status == LessonSessionStatus.paused) {
        replay = await _store.resume(
          userId: replay.userId,
          sessionId: replay.id,
          now: request.now,
        );
      }
      await _showCurrentOrNextQuestion(replay);
    } catch (error) {
      _set(LessonFlowState(phase: LessonFlowPhase.error, error: error));
    }
  }

  Future<void> submitOrder(Map<int, String> itemIdByMarker) async {
    final current = _requireAnswering<BuiltPhotoOrderQuestion>();
    final attempt = gradePhotoOrder(
      current.question,
      PhotoOrderSubmission(
        attemptId: _attemptIdFactory(),
        questionId: current.id,
        itemIdByMarker: itemIdByMarker,
      ),
    );
    await _commit(attempt, current);
  }

  Future<void> submitLetterFill(String answer) async {
    final current = _requireAnswering<BuiltPhotoLetterFillQuestion>();
    final attempt = gradePhotoLetterFill(
      current.question,
      PhotoLetterFillSubmission(
        attemptId: _attemptIdFactory(),
        questionId: current.id,
        answer: answer,
      ),
    );
    await _commit(attempt, current);
  }

  void continueAfterFeedback() {
    if (_state.phase != LessonFlowPhase.feedback) {
      throw StateError('Lesson is not showing feedback.');
    }
    final session = _state.session!;
    if (session.status == LessonSessionStatus.completed) {
      _nextQuestion = null;
      _set(LessonFlowState(
        phase: LessonFlowPhase.completed,
        session: session,
      ));
      return;
    }
    final next = _nextQuestion;
    if (next == null) {
      throw StateError('A pending lesson must have a next question.');
    }
    _nextQuestion = null;
    _set(LessonFlowState(
      phase: LessonFlowPhase.answering,
      session: session,
      question: next,
    ));
  }

  Future<void> checkpointDraft(String? draftJson) async {
    final session = _state.session;
    if (session == null ||
        session.status != LessonSessionStatus.active ||
        _state.phase != LessonFlowPhase.answering) {
      return;
    }
    await _store.saveDraft(
      userId: session.userId,
      sessionId: session.id,
      currentQuestionJson: _state.question?.encode(),
      draftJson: draftJson,
      now: _now(),
    );
  }

  Future<void> resume({required DateTime now}) async {
    final session = _state.session;
    if (session == null || session.status != LessonSessionStatus.paused) {
      return;
    }
    try {
      final rewardWindowEndsAt = _activeRewardWindowEndsAt;
      if ((session.mode == LessonSessionMode.daily &&
              !now.isBefore(session.nextDayEndsAt)) ||
          (rewardWindowEndsAt != null && !now.isBefore(rewardWindowEndsAt))) {
        final expired = await _store.expire(
          userId: session.userId,
          sessionId: session.id,
          now: now,
        );
        _set(LessonFlowState(
          phase: LessonFlowPhase.expired,
          session: expired,
        ));
        return;
      }
      if (!await _sourceLoader.isSessionSourceAvailable(session)) {
        final blocked = await _store.block(
          userId: session.userId,
          sessionId: session.id,
          now: now,
        );
        _set(LessonFlowState(
          phase: LessonFlowPhase.blocked,
          session: blocked,
        ));
        return;
      }
      final resumed = await _store.resume(
        userId: session.userId,
        sessionId: session.id,
        now: now,
      );
      await _showCurrentOrNextQuestion(resumed);
    } catch (error) {
      _set(LessonFlowState(
        phase: LessonFlowPhase.error,
        session: session,
        error: error,
      ));
    }
  }

  Future<void> pause({String? draftJson, required DateTime now}) async {
    final session = _state.session;
    if (session == null ||
        session.status != LessonSessionStatus.active ||
        !{
          LessonFlowPhase.answering,
          LessonFlowPhase.feedback,
          LessonFlowPhase.ready,
        }.contains(_state.phase)) {
      return;
    }
    final persistedQuestion = _nextQuestion ?? _state.question;
    final persistedDraft =
        _state.phase == LessonFlowPhase.feedback ? null : draftJson;
    try {
      final paused = await _store.pause(
        userId: session.userId,
        sessionId: session.id,
        currentQuestionJson: persistedQuestion?.encode(),
        draftJson: persistedDraft,
        now: now,
      );
      _set(LessonFlowState(
        phase: LessonFlowPhase.paused,
        session: paused,
        question: persistedQuestion,
      ));
    } catch (error) {
      _set(LessonFlowState(
        phase: LessonFlowPhase.error,
        session: session,
        error: error,
      ));
    }
  }

  Future<void> abandon({required DateTime now}) async {
    final session = _state.session;
    if (session == null) {
      return;
    }
    try {
      final abandoned = await _store.abandon(
        userId: session.userId,
        sessionId: session.id,
        now: now,
      );
      _nextQuestion = null;
      _set(LessonFlowState(
        phase: LessonFlowPhase.abandoned,
        session: abandoned,
      ));
    } catch (error) {
      _set(LessonFlowState(
        phase: LessonFlowPhase.error,
        session: session,
        error: error,
      ));
    }
  }

  Future<void> _showCurrentOrNextQuestion(
    LessonSession session, {
    LessonSourceBuildResult? source,
  }) async {
    BuiltLessonQuestion question;
    final encoded = session.currentQuestionJson;
    if (encoded != null) {
      question = _questionBuilder.decode(encoded);
      if (!session.mastery.pendingQueue.toSet().containsAll(question.itemIds)) {
        throw const FormatException(
          'Persisted question does not match the pending queue.',
        );
      }
    } else {
      question = _questionBuilder.next(
        mastery: session.mastery,
        items: session.items,
        questionId: _questionIdFactory(),
        preference: _gamePreference,
      )!;
      await _store.saveDraft(
        userId: session.userId,
        sessionId: session.id,
        currentQuestionJson: question.encode(),
        draftJson: session.draftJson,
        now: session.updatedAt,
      );
      session = (await _store.get(
        userId: session.userId,
        sessionId: session.id,
      ))!;
    }
    _set(LessonFlowState(
      phase: LessonFlowPhase.answering,
      session: session,
      question: question,
      source: source,
    ));
  }

  T _requireAnswering<T extends BuiltLessonQuestion>() {
    if (_state.phase != LessonFlowPhase.answering || _state.question is! T) {
      throw StateError('The active question does not accept this submission.');
    }
    return _state.question! as T;
  }

  Future<void> _commit(
    LessonGradedAttempt attempt,
    BuiltLessonQuestion submittedQuestion,
  ) async {
    final session = _state.session!;
    _set(LessonFlowState(
      phase: LessonFlowPhase.submitting,
      session: session,
      question: submittedQuestion,
    ));
    try {
      final predicted = applyLessonAttempt(session.mastery, attempt);
      final nextQuestion = predicted.state.isComplete
          ? null
          : _questionBuilder.next(
              mastery: predicted.state,
              items: session.items,
              questionId: _questionIdFactory(),
              preference: _gamePreference,
            );
      final persisted = await _store.applyAttempt(
        userId: session.userId,
        sessionId: session.id,
        attempt: attempt,
        now: _now(),
        nextQuestionJson: nextQuestion?.encode(),
      );
      _nextQuestion = nextQuestion;
      _set(LessonFlowState(
        phase: LessonFlowPhase.feedback,
        session: persisted.session,
        question: submittedQuestion,
        feedbackAttempt: persisted.application.attempt,
      ));
    } catch (error) {
      _set(LessonFlowState(
        phase: LessonFlowPhase.error,
        session: session,
        question: submittedQuestion,
        error: error,
      ));
    }
  }

  void _set(LessonFlowState value) {
    _state = value;
    notifyListeners();
  }

  static bool _canExpire(LessonSessionStatus status) => {
        LessonSessionStatus.active,
        LessonSessionStatus.paused,
        LessonSessionStatus.blocked,
      }.contains(status);

  static bool _isTerminal(LessonSessionStatus status) => {
        LessonSessionStatus.completed,
        LessonSessionStatus.abandoned,
        LessonSessionStatus.expired,
      }.contains(status);

  static LessonFlowState _terminalState(
    LessonSession session, {
    LessonSourceBuildResult? source,
  }) {
    final phase = switch (session.status) {
      LessonSessionStatus.completed => LessonFlowPhase.completed,
      LessonSessionStatus.abandoned => LessonFlowPhase.abandoned,
      LessonSessionStatus.expired => LessonFlowPhase.expired,
      _ => throw StateError('Session is not terminal.'),
    };
    return LessonFlowState(phase: phase, session: session, source: source);
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
