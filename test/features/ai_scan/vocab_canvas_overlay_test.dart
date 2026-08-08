import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render ảnh và CustomPaint với box đã chuẩn hóa', (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );
    const word = VocabDetection(
      word: 'apple',
      phonetic: '/ˈæp.əl/',
      meaning: 'quả táo',
      x: 0.1,
      y: 0.2,
      w: 0.3,
      h: 0.1,
    );

    final imageProvider = MemoryImage(imageBytes);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabCanvasOverlay(
            imageProvider: imageProvider,
            words: const [word],
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        imageProvider,
        tester.element(find.byType(VocabCanvasOverlay)),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final overlayPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VocabOverlayPainter,
    );
    expect(overlayPaint, findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(overlayPaint);
    final painter = customPaint.painter! as VocabOverlayPainter;
    expect(painter.words, const [word]);
    expect(tester.takeException(), isNull);
  });
}
