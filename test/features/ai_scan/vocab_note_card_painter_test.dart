import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_note_card_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses one fixed typography set for every card tier', () {
    expect(vocabNoteCardWordStyle.fontSize, 13);
    expect(vocabNoteCardWordStyle.fontWeight, FontWeight.w800);
    expect(vocabNoteCardPhoneticStyle.fontSize, 9.5);
    expect(vocabNoteCardPhoneticStyle.fontStyle, FontStyle.italic);
    expect(vocabNoteCardMeaningStyle.fontSize, 10);
    expect(vocabNoteCardMeaningStyle.fontWeight, FontWeight.w600);
  });

  test('stable word rotation repeats and remains between one and three degrees',
      () {
    final first = stableWordJitterRadians('cabinet');
    final second = stableWordJitterRadians('cabinet');
    const minimum = 3.141592653589793 / 180;
    const maximum = maxCardJitterDegrees * 3.141592653589793 / 180;

    expect(second, first);
    expect(first.abs(), inInclusiveRange(minimum, maximum));
    expect(
      stableWordJitterRadians('globe'),
      isNot(stableWordJitterRadians('cabinet')),
    );
  });

  test('stable string hash does not depend on invocation order', () {
    final cabinet = stableStringHash('cabinet');
    stableStringHash('another-word');

    expect(stableStringHash('cabinet'), cabinet);
  });

  test('measures text-driven cards within 160px without fixed height', () {
    const short = VocabDetection(
      word: 'book',
      phonetic: '/bʊk/',
      meaning: 'sách',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    const long = VocabDetection(
      word: 'extraordinarily-long-cabinet-name',
      phonetic: '/ˈkæbɪnət-with-a-long-phonetic-value/',
      meaning: 'một cách giải nghĩa tiếng Việt rất dài và không bị cắt',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    final shortSize = measureVocabNoteCardSize(short);
    final longSize = measureVocabNoteCardSize(long);

    expect(shortSize.width, lessThanOrEqualTo(vocabNoteCardMaxWidth));
    expect(longSize.width, lessThanOrEqualTo(vocabNoteCardMaxWidth));
    expect(longSize.width, greaterThan(shortSize.width));
    expect(longSize.height, greaterThan(shortSize.height));
  });

  testWidgets('paints complete and missing metadata without overflow errors', (
    tester,
  ) async {
    const complete = VocabDetection(
      word: 'extraordinarily-long-cabinet-name',
      phonetic: '/ˈkæbɪnət-with-a-long-phonetic-value/',
      meaning: 'một cách giải nghĩa tiếng Việt rất dài',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    const missingMetadata = VocabDetection(
      word: 'chair',
      phonetic: '   ',
      meaning: '\n',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    final completeSize = measureVocabNoteCardSize(complete);
    final missingSize = measureVocabNoteCardSize(missingMetadata);

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            CustomPaint(
              size: completeSize,
              painter: const VocabNoteCardPainter(
                detection: complete,
                index: 1,
              ),
            ),
            CustomPaint(
              size: missingSize,
              painter: const VocabNoteCardPainter(
                detection: missingMetadata,
                index: 12,
              ),
            ),
          ],
        ),
      ),
    );

    final noteCards = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VocabNoteCardPainter,
    );
    expect(noteCards, findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
