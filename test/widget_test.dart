import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capy_vocab/app.dart';

void main() {
  testWidgets('App khởi động không lỗi', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CapyVocabApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
