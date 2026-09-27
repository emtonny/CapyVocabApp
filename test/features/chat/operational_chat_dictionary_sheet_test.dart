import 'dart:async';

import 'package:capy_vocab/features/chat/presentation/operational_chat_dictionary_sheet.dart';
import 'package:capy_vocab/features/library/domain/entities/local_vocabulary_match.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Future<List<LocalVocabularyMatch>> Function() lookup) {
  return MaterialApp(
    home: Scaffold(
      body: OperationalChatDictionarySheet(query: 'cup', lookup: lookup),
    ),
  );
}

void main() {
  testWidgets('shows local-only loading and a corrected vocabulary result',
      (tester) async {
    final completer = Completer<List<LocalVocabularyMatch>>();
    await tester.pumpWidget(_app(() => completer.future));

    expect(find.byKey(const Key('chat-dictionary-loading')), findsOneWidget);
    expect(find.textContaining('không dùng mạng'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('chat-dictionary-close'))),
      const Size(48, 48),
    );

    completer.complete([
      LocalVocabularyMatch(
        word: 'Cup',
        phonetic: '/kʌp/',
        meaningVi: 'cái cốc',
        partOfSpeech: 'noun',
        exampleEn: 'A cup of tea.',
        exampleVi: 'Một tách trà.',
        occurrenceCount: 2,
        corrected: true,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-dictionary-results')), findsOneWidget);
    expect(find.text('Cup'), findsOneWidget);
    expect(find.text('/kʌp/'), findsOneWidget);
    expect(find.text('cái cốc'), findsOneWidget);
    expect(find.text('Library trên máy · 2 nguồn đã lưu'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and failure states do not invent a network fallback',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(_app(() async {
      attempts++;
      if (attempts == 1) throw StateError('local read failed');
      return const [];
    }));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-dictionary-error')), findsOneWidget);
    final retryButton = find.widgetWithText(FilledButton, 'Thử lại');
    expect(tester.getSize(retryButton).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('chat-dictionary-empty')), findsOneWidget);
    expect(find.textContaining('Library trên máy'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
