import 'dart:convert';

import '../domain/lesson_game.dart';

enum LessonGamePreference { mixed, order, fill }

sealed class BuiltLessonQuestion {
  const BuiltLessonQuestion();

  String get id;
  LessonGameType get gameType;
  List<String> get itemIds;

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());
}

final class BuiltPhotoOrderQuestion extends BuiltLessonQuestion {
  BuiltPhotoOrderQuestion(this.question);

  final PhotoOrderQuestion question;

  @override
  String get id => question.id;

  @override
  LessonGameType get gameType => LessonGameType.photoOrderQuiz;

  @override
  List<String> get itemIds => List.unmodifiable(
        question.targets.map((target) => target.itemId),
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'photo_order_quiz',
        'id': id,
        'targets': [
          for (final target in question.targets)
            {'marker': target.marker, 'item_id': target.itemId},
        ],
      };
}

final class BuiltPhotoLetterFillQuestion extends BuiltLessonQuestion {
  BuiltPhotoLetterFillQuestion(this.question);

  final PhotoLetterFillQuestion question;

  @override
  String get id => question.id;

  @override
  LessonGameType get gameType => LessonGameType.photoLetterFill;

  @override
  List<String> get itemIds => [question.itemId];

  @override
  Map<String, Object?> toJson() => {
        'type': 'photo_letter_fill',
        'id': id,
        'item_id': question.itemId,
        'expected_answer': question.expectedAnswer,
      };
}

final class LessonQuestionBuilder {
  const LessonQuestionBuilder();

  BuiltLessonQuestion? next({
    required LessonMasteryState mastery,
    required Iterable<LessonMasteryItem> items,
    required String questionId,
    LessonGamePreference preference = LessonGamePreference.mixed,
  }) {
    if (questionId.trim().isEmpty) {
      throw ArgumentError.value(questionId, 'questionId', 'must not be blank');
    }
    if (mastery.isComplete) {
      return null;
    }
    final itemById = {for (final item in items) item.id: item};
    if (!itemById.keys.toSet().containsAll(mastery.itemIds) ||
        itemById.length != mastery.itemIds.length) {
      throw ArgumentError('items must match the mastery snapshot');
    }

    if (preference == LessonGamePreference.fill) {
      final item = itemById[mastery.pendingQueue.first]!;
      return BuiltPhotoLetterFillQuestion(
        PhotoLetterFillQuestion(
          id: questionId,
          itemId: item.id,
          expectedAnswer: item.answer,
        ),
      );
    }

    final pendingByPhotoNote = <String, List<LessonMasteryItem>>{};
    for (final itemId in mastery.pendingQueue) {
      final item = itemById[itemId]!;
      pendingByPhotoNote.putIfAbsent(item.photoNoteId, () => []).add(item);
    }
    for (final group in pendingByPhotoNote.values) {
      if (group.length < 2) {
        continue;
      }
      final selected = group.take(4).toList(growable: false);
      return BuiltPhotoOrderQuestion(
        PhotoOrderQuestion(
          id: questionId,
          targets: [
            for (var index = 0; index < selected.length; index++)
              PhotoOrderTarget(
                marker: index + 1,
                itemId: selected[index].id,
              ),
          ],
        ),
      );
    }

    final item = itemById[mastery.pendingQueue.first]!;
    return BuiltPhotoLetterFillQuestion(
      PhotoLetterFillQuestion(
        id: questionId,
        itemId: item.id,
        expectedAnswer: item.answer,
      ),
    );
  }

  BuiltLessonQuestion decode(String encoded) {
    final json = (jsonDecode(encoded) as Map).cast<String, Object?>();
    return switch (json['type']) {
      'photo_order_quiz' => BuiltPhotoOrderQuestion(
          PhotoOrderQuestion(
            id: json['id']! as String,
            targets: [
              for (final target in (json['targets']! as List))
                PhotoOrderTarget(
                  marker: (target as Map)['marker']! as int,
                  itemId: target['item_id']! as String,
                ),
            ],
          ),
        ),
      'photo_letter_fill' => BuiltPhotoLetterFillQuestion(
          PhotoLetterFillQuestion(
            id: json['id']! as String,
            itemId: json['item_id']! as String,
            expectedAnswer: json['expected_answer']! as String,
          ),
        ),
      final value => throw FormatException(
          'Unsupported lesson question type: $value',
        ),
    };
  }
}
