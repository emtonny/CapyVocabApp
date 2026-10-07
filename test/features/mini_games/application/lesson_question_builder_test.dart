import 'package:capy_vocab/features/mini_games/application/lesson_question_builder.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = LessonQuestionBuilder();

  test('prefers a 2 to 4 target order question from one photo', () {
    final items = [
      _item('single', photoNoteId: 'photo-a'),
      _item('one', photoNoteId: 'photo-b'),
      _item('two', photoNoteId: 'photo-b'),
      _item('three', photoNoteId: 'photo-b'),
      _item('four', photoNoteId: 'photo-b'),
      _item('five', photoNoteId: 'photo-b'),
    ];
    final question = builder.next(
      mastery: LessonMasteryState.initial(items.map((item) => item.id)),
      items: items,
      questionId: 'question-1',
    );

    expect(question, isA<BuiltPhotoOrderQuestion>());
    expect(question!.itemIds, ['one', 'two', 'three', 'four']);
    final order = (question as BuiltPhotoOrderQuestion).question;
    expect(order.targets.map((target) => target.marker), [1, 2, 3, 4]);
  });

  test('uses letter fill for an isolated pending item', () {
    final items = [_item('apple', photoNoteId: 'photo-a', answer: 'Apple')];
    final question = builder.next(
      mastery: LessonMasteryState.initial(['apple']),
      items: items,
      questionId: 'question-2',
    );

    expect(question, isA<BuiltPhotoLetterFillQuestion>());
    expect(
      (question as BuiltPhotoLetterFillQuestion).question.expectedAnswer,
      'Apple',
    );
  });

  test('review preference can force letter fill with multiple same-photo items',
      () {
    final items = [
      _item('apple', photoNoteId: 'photo-a'),
      _item('cup', photoNoteId: 'photo-a'),
    ];
    final question = builder.next(
      mastery: LessonMasteryState.initial(['apple', 'cup']),
      items: items,
      questionId: 'fill-preferred',
      preference: LessonGamePreference.fill,
    );

    expect(question, isA<BuiltPhotoLetterFillQuestion>());
    expect(question!.itemIds, ['apple']);
  });

  test('round trips both frozen question formats', () {
    final items = [
      _item('one', photoNoteId: 'photo-a'),
      _item('two', photoNoteId: 'photo-a'),
    ];
    final order = builder.next(
      mastery: LessonMasteryState.initial(['one', 'two']),
      items: items,
      questionId: 'order-question',
    )!;
    final decodedOrder = builder.decode(order.encode());
    expect(decodedOrder.gameType, LessonGameType.photoOrderQuiz);
    expect(decodedOrder.itemIds, ['one', 'two']);

    final fill = builder.next(
      mastery: LessonMasteryState.initial(['one']),
      items: [items.first],
      questionId: 'fill-question',
    )!;
    final decodedFill = builder.decode(fill.encode());
    expect(decodedFill.gameType, LessonGameType.photoLetterFill);
    expect(decodedFill.itemIds, ['one']);
  });

  test('returns no question after full mastery', () {
    final item = _item('apple', photoNoteId: 'photo-a');
    var mastery = LessonMasteryState.initial(['apple']);
    mastery = applyLessonAttempt(
      mastery,
      LessonGradedAttempt(
        attemptId: 'attempt-1',
        questionId: 'question-1',
        gameType: LessonGameType.photoLetterFill,
        payloadFingerprint: 'correct',
        verdicts: const [
          LessonItemVerdict(itemId: 'apple', isCorrect: true),
        ],
      ),
    ).state;

    expect(
      builder.next(
        mastery: mastery,
        items: [item],
        questionId: 'question-2',
      ),
      isNull,
    );
  });
}

LessonMasteryItem _item(
  String id, {
  required String photoNoteId,
  String? answer,
}) =>
    LessonMasteryItem(
      id: id,
      photoNoteId: photoNoteId,
      mediaAssetId: 'media-$photoNoteId',
      imageRelativePath: 'capy_scans/$photoNoteId.jpg',
      imageWidth: 100,
      imageHeight: 100,
      targetId: 'target-$id',
      boundingBox: LessonNormalizedBoundingBox(
        x: 0.1,
        y: 0.1,
        width: 0.2,
        height: 0.2,
      ),
      answer: answer ?? id,
      sourceRevision: 'revision-$id',
    );
