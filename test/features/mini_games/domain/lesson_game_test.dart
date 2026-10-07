import 'package:capy_vocab/features/mini_games/domain/lesson_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('answer normalization', () {
    test('uses NFC, trim and lowercase without removing punctuation', () {
      expect(normalizeLessonAnswer('  CAFÉ  '), 'café');
      expect(normalizeLessonAnswer('Cafe\u0301'), 'café');
      expect(normalizeLessonAnswer(" Ice-Cream's "), "ice-cream's");
      expect(normalizeLessonAnswer('ice  cream'), 'ice  cream');
    });
  });

  group('photo order grading', () {
    final question = PhotoOrderQuestion(
      id: 'order-question',
      targets: [
        PhotoOrderTarget(marker: 1, itemId: 'apple'),
        PhotoOrderTarget(marker: 2, itemId: 'cup'),
        PhotoOrderTarget(marker: 3, itemId: 'book'),
      ],
    );

    test('grades each marker independently', () {
      final attempt = gradePhotoOrder(
        question,
        PhotoOrderSubmission(
          attemptId: 'attempt-1',
          questionId: question.id,
          itemIdByMarker: const {1: 'apple', 2: 'book', 3: 'cup'},
        ),
      );

      expect(
        attempt.verdicts.map((verdict) => verdict.isCorrect),
        [true, false, false],
      );
    });

    test('rejects incomplete or non-permutation answers', () {
      expect(
        () => gradePhotoOrder(
          question,
          PhotoOrderSubmission(
            attemptId: 'attempt-2',
            questionId: question.id,
            itemIdByMarker: const {1: 'apple', 2: 'cup'},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => gradePhotoOrder(
          question,
          PhotoOrderSubmission(
            attemptId: 'attempt-3',
            questionId: question.id,
            itemIdByMarker: const {1: 'apple', 2: 'cup', 3: 'foreign'},
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('photo letter fill grading', () {
    final question = PhotoLetterFillQuestion(
      id: 'fill-question',
      itemId: 'cafe',
      expectedAnswer: 'Café',
    );

    test('accepts canonically equivalent Unicode and case', () {
      final attempt = gradePhotoLetterFill(
        question,
        PhotoLetterFillSubmission(
          attemptId: 'fill-attempt-1',
          questionId: question.id,
          answer: '  CAFE\u0301 ',
        ),
      );

      expect(attempt.verdicts.single.isCorrect, isTrue);
    });

    test('does not guess plural or accept blank input', () {
      final plural = gradePhotoLetterFill(
        question,
        PhotoLetterFillSubmission(
          attemptId: 'fill-attempt-2',
          questionId: question.id,
          answer: 'cafés',
        ),
      );

      expect(plural.verdicts.single.isCorrect, isFalse);
      expect(
        () => gradePhotoLetterFill(
          question,
          PhotoLetterFillSubmission(
            attemptId: 'fill-attempt-3',
            questionId: question.id,
            answer: '   ',
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('mastery queue', () {
    test('masters correct items and moves wrong items to the queue tail', () {
      final state = LessonMasteryState.initial(['apple', 'cup', 'book']);
      final attempt = LessonGradedAttempt(
        attemptId: 'attempt-1',
        questionId: 'question-1',
        gameType: LessonGameType.photoOrderQuiz,
        payloadFingerprint: 'payload-1',
        verdicts: const [
          LessonItemVerdict(itemId: 'apple', isCorrect: true),
          LessonItemVerdict(itemId: 'cup', isCorrect: false),
        ],
      );

      final result = applyLessonAttempt(state, attempt);

      expect(result.state.masteredItemIds, {'apple'});
      expect(result.state.pendingQueue, ['book', 'cup']);
      expect(result.state.completedCount, 1);
      expect(result.state.isComplete, isFalse);
    });

    test('replaying the same attempt is idempotent', () {
      final state = LessonMasteryState.initial(['apple']);
      final attempt = _attempt(
        attemptId: 'attempt-1',
        itemId: 'apple',
        isCorrect: false,
        payload: 'apple-wrong',
      );
      final first = applyLessonAttempt(state, attempt);
      final replay = applyLessonAttempt(first.state, attempt);

      expect(replay.isReplay, isTrue);
      expect(replay.state, same(first.state));
      expect(replay.state.pendingQueue, ['apple']);
      expect(replay.state.attempts, hasLength(1));
    });

    test('same attempt ID with a different payload conflicts', () {
      final state = LessonMasteryState.initial(['apple']);
      final first = applyLessonAttempt(
        state,
        _attempt(
          attemptId: 'attempt-1',
          itemId: 'apple',
          isCorrect: false,
          payload: 'apple-wrong',
        ),
      );

      expect(
        () => applyLessonAttempt(
          first.state,
          _attempt(
            attemptId: 'attempt-1',
            itemId: 'apple',
            isCorrect: true,
            payload: 'apple-correct',
          ),
        ),
        throwsA(isA<LessonAttemptConflict>()),
      );
    });

    test('only the final pending item produces 100 percent mastery', () {
      var state = LessonMasteryState.initial(['apple', 'cup']);
      state = applyLessonAttempt(
        state,
        _attempt(
          attemptId: 'attempt-1',
          itemId: 'apple',
          isCorrect: true,
          payload: 'apple-correct',
        ),
      ).state;

      expect(state.completedCount, 1);
      expect(state.totalCount, 2);
      expect(state.isComplete, isFalse);

      state = applyLessonAttempt(
        state,
        _attempt(
          attemptId: 'attempt-2',
          itemId: 'cup',
          isCorrect: true,
          payload: 'cup-correct',
        ),
      ).state;

      expect(state.completedCount, 2);
      expect(state.isComplete, isTrue);
    });

    test('rejects a stale new attempt for an item already mastered', () {
      var state = LessonMasteryState.initial(['apple']);
      state = applyLessonAttempt(
        state,
        _attempt(
          attemptId: 'attempt-1',
          itemId: 'apple',
          isCorrect: true,
          payload: 'apple-correct',
        ),
      ).state;

      expect(
        () => applyLessonAttempt(
          state,
          _attempt(
            attemptId: 'attempt-2',
            itemId: 'apple',
            isCorrect: true,
            payload: 'stale',
          ),
        ),
        throwsStateError,
      );
    });
  });

  test('ads are allowed only outside active gameplay', () {
    expect(LessonStage.intro.allowsAds, isTrue);
    expect(LessonStage.playing.allowsAds, isFalse);
    expect(LessonStage.feedback.allowsAds, isFalse);
    expect(LessonStage.completed.allowsAds, isTrue);
  });
}

LessonGradedAttempt _attempt({
  required String attemptId,
  required String itemId,
  required bool isCorrect,
  required String payload,
}) =>
    LessonGradedAttempt(
      attemptId: attemptId,
      questionId: 'question-$attemptId',
      gameType: LessonGameType.photoLetterFill,
      payloadFingerprint: payload,
      verdicts: [LessonItemVerdict(itemId: itemId, isCorrect: isCorrect)],
    );
