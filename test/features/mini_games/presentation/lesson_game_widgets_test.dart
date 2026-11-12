import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_question_builder.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_game.dart';
import 'package:capy_vocab/features/mini_games/photo_letter_fill/presentation/screens/photo_letter_fill_screen.dart';
import 'package:capy_vocab/features/mini_games/photo_order_quiz/presentation/screens/photo_order_quiz_screen.dart';
import 'package:capy_vocab/features/mini_games/photo_order_quiz/presentation/widgets/order_number_chip.dart';
import 'package:capy_vocab/features/mini_games/presentation/widgets/lesson_photo_view.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:capy_vocab/features/mini_games/photo_letter_fill/presentation/screens/photo_multi_fill_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('each bulb reveals three hints independently and restores levels',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [_item('apple', 'Apple', .1), _item('cup', 'Cup', .5)];
    final question =
        BuiltPhotoMultiFillQuestion(PhotoOrderQuestion(id: 'hints', targets: [
      PhotoOrderTarget(marker: 1, itemId: 'apple'),
      PhotoOrderTarget(marker: 2, itemId: 'cup')
    ]));
    String? draft;
    Widget game({String? saved}) => _app(PhotoMultiFillScreen(
        question: question,
        items: items,
        mediaLoader: const _MemoryMediaLoader(),
        initialDraftJson: saved,
        onChanged: (value) => draft = value,
        onSubmit: (_) {},
        loadHints: (item) async => item.id == 'apple'
            ? const LessonWordHints(meaningVi: 'Quả táo', phonetic: '/ˈæp.əl/')
            : const LessonWordHints()));
    await tester.pumpWidget(game());
    await tester.pumpAndSettle();
    final appleBulb = find.byKey(const Key('photo-fill-hint-apple'));
    expect(find.textContaining('Quả táo'), findsNothing);
    await tester.ensureVisible(appleBulb);
    await tester.tap(appleBulb);
    await tester.pumpAndSettle();
    expect(find.text('Nghĩa: Quả táo'), findsOneWidget);
    expect(find.textContaining('Phiên âm:'), findsNothing);
    expect(find.byKey(const Key('photo-fill-hint-panel-cup')), findsNothing);
    await tester.tap(appleBulb);
    await tester.pumpAndSettle();
    expect(find.text('Phiên âm: /ˈæp.əl/'), findsOneWidget);
    expect(find.text('Từ vựng: Apple'), findsNothing);
    await tester.tap(appleBulb);
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng: Apple'), findsOneWidget);
    expect(tester.widget<StickerButton>(appleBulb).onPressed, isNotNull);
    expect(
        tester
            .widget<TextField>(
                find.byKey(const Key('photo-multi-fill-input-apple')))
            .controller!
            .text,
        isEmpty);
    expect(jsonDecode(draft!)['hint_levels'], {'apple': 3, 'cup': 0});
    final saved = draft;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(game(saved: saved));
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng: Apple'), findsNothing);
    await tester.ensureVisible(appleBulb);
    await tester.tap(appleBulb);
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng: Apple'), findsOneWidget);
    final cupBulb = find.byKey(const Key('photo-fill-hint-cup'));
    await tester.ensureVisible(cupBulb);
    await tester.tap(cupBulb);
    await tester.pumpAndSettle();
    expect(find.text('Nghĩa: Chưa có nghĩa tiếng Việt.'), findsOneWidget);
    await tester.tap(cupBulb);
    await tester.pumpAndSettle();
    expect(find.text('Phiên âm: Chưa có phiên âm.'), findsOneWidget);
    await tester.tap(cupBulb);
    await tester.pumpAndSettle();
    expect(find.text('Từ vựng: Cup'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Từ vựng: Cup'), findsOneWidget);
    // Replaying the third hint starts a fresh five-second reading window.
    await tester.tap(cupBulb);
    await tester.pumpAndSettle();
    expect(jsonDecode(draft!)['hint_levels'], {'apple': 3, 'cup': 3});
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Từ vựng: Apple'), findsNothing);
    expect(find.text('Từ vựng: Cup'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('photo-fill-hint-panel-cup')), findsNothing);
    expect(tester.widget<StickerButton>(cupBulb).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo marker badge stays legible when its bbox is tiny',
      (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 320,
          child: LessonPhotoView(
            mediaLoader: const _MemoryMediaLoader(),
            relativePath: 'capy_scans/photo.jpg',
            imageWidth: 4000,
            imageHeight: 3000,
            markers: [
              LessonPhotoMarker(
                box: LessonNormalizedBoundingBox(
                  x: 0.99,
                  y: 0.01,
                  width: 0.005,
                  height: 0.005,
                ),
                semanticLabel: 'Đồ vật số 1',
                number: 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(const Key('lesson-photo-marker-badge-1'));
    expect(badge, findsOneWidget);
    expect(tester.getSize(badge), const Size.square(36));
    final badgeDecoration =
        tester.widget<Container>(badge).decoration! as BoxDecoration;
    expect(badgeDecoration.color, AppColors.yellow);
    expect(badgeDecoration.border!.top.color, AppColors.ink);

    final frame = find.byKey(const Key('lesson-photo-marker-frame-1'));
    final frameDecoration =
        tester.widget<Container>(frame).decoration! as BoxDecoration;
    expect(frameDecoration.border!.top.color, AppColors.yellow);
    expect(frameDecoration.boxShadow!.single.color, AppColors.ink);

    final decodedImage = tester.widget<Image>(find.byType(Image));
    final resizedImage = decodedImage.image as ResizeImage;
    expect(resizedImage.width, allOf(greaterThan(0), lessThan(4000)));
    expect(resizedImage.height, allOf(greaterThan(0), lessThan(3000)));
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('order game supports tap-card then tap-slot and 48dp targets',
      (tester) async {
    final items = [_item('apple', 'Apple', 0.1), _item('cup', 'Cup', 0.5)];
    final question = BuiltPhotoOrderQuestion(
      PhotoOrderQuestion(
        id: 'order-1',
        targets: [
          PhotoOrderTarget(marker: 1, itemId: 'apple'),
          PhotoOrderTarget(marker: 2, itemId: 'cup'),
        ],
      ),
    );
    Map<int, String>? submitted;
    final drafts = <String>[];

    await tester.pumpWidget(
      _app(
        PhotoOrderQuizScreen(
          question: question,
          items: items,
          mediaLoader: const _MemoryMediaLoader(),
          onChanged: drafts.add,
          onSubmit: (value) => submitted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chipSize = tester.getSize(find.byType(OrderNumberChip).first);
    expect(chipSize.width, greaterThanOrEqualTo(48));
    expect(chipSize.height, greaterThanOrEqualTo(48));
    expect(
      tester
          .widget<StickerButton>(find.byKey(const Key('photo-order-submit')))
          .onPressed,
      isNull,
    );

    final appleCard = find.byKey(const Key('photo-order-card-apple'));
    final firstSlot = find.byKey(const Key('photo-order-slot-1'));
    final cupCard = find.byKey(const Key('photo-order-card-cup'));
    final secondSlot = find.byKey(const Key('photo-order-slot-2'));
    await tester.ensureVisible(appleCard);
    await tester.tap(appleCard);
    await tester.pump();
    await tester.ensureVisible(firstSlot);
    await tester.tap(firstSlot);
    await tester.pump();
    await tester.ensureVisible(cupCard);
    await tester.tap(cupCard);
    await tester.pump();
    await tester.ensureVisible(secondSlot);
    await tester.tap(secondSlot);
    await tester.pump();

    expect(drafts, isNotEmpty);
    final submit = find.byKey(const Key('photo-order-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(submitted, {1: 'apple', 2: 'cup'});
  });

  testWidgets(
      'numbered fill restores blank cells, wraps and submits word spaces',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [_item('ice', 'Ice cream', .1), _item('cup', 'Cup', .5)];
    final question =
        BuiltPhotoMultiFillQuestion(PhotoOrderQuestion(id: 'multi', targets: [
      PhotoOrderTarget(marker: 1, itemId: 'ice'),
      PhotoOrderTarget(marker: 2, itemId: 'cup'),
    ]));
    Map<String, String>? submitted;
    String? draft;
    await tester.pumpWidget(_app(PhotoMultiFillScreen(
      question: question,
      items: items,
      mediaLoader: const _MemoryMediaLoader(),
      initialDraftJson:
          '{"question_id":"multi","letters":{"cup":["c","u","p"]}}',
      onChanged: (value) => draft = value,
      onSubmit: (value) => submitted = value,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(
        find.byKey(const Key('lesson-photo-marker-badge-1')), findsOneWidget);
    expect(
        find.byKey(const Key('lesson-photo-marker-badge-2')), findsOneWidget);
    expect(
        tester
            .widget<StickerButton>(
                find.byKey(const Key('photo-multi-fill-submit')))
            .onPressed,
        isNull);
    final field = find.byKey(const Key('photo-multi-fill-input-ice'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'ice cream');
    await tester.pump();
    expect(draft, contains('question_id'));
    final submit = find.byKey(const Key('photo-multi-fill-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    expect(submitted, {'ice': 'ice cream', 'cup': 'cup'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('letter game uses a real TextField and submits Unicode input',
      (tester) async {
    final item = _item('cafe', 'Café', 0.2);
    final question = BuiltPhotoLetterFillQuestion(
      PhotoLetterFillQuestion(
        id: 'fill-1',
        itemId: item.id,
        expectedAnswer: item.answer,
      ),
    );
    String? submitted;
    String? draft;

    await tester.pumpWidget(
      _app(
        PhotoLetterFillScreen(
          question: question,
          item: item,
          mediaLoader: const _MemoryMediaLoader(),
          onChanged: (value) => draft = value,
          onSubmit: (value) => submitted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('photo-fill-text-field')),
      ' CAFE\u0301 ',
    );
    await tester.pump();
    expect(draft, contains('CAFE'));

    final submit = find.byKey(const Key('photo-fill-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(submitted, ' CAFE\u0301 ');
  });

  testWidgets('numbered word input keeps focus through composition and edits',
      (tester) async {
    final item = _item('cafe', 'Café', .2);
    final question = BuiltPhotoMultiFillQuestion(PhotoOrderQuestion(
        id: 'ime', targets: [PhotoOrderTarget(marker: 1, itemId: item.id)]));
    Map<String, String>? submitted;
    await tester.pumpWidget(_app(PhotoMultiFillScreen(
        question: question,
        items: [item],
        mediaLoader: const _MemoryMediaLoader(),
        onChanged: (_) {},
        onSubmit: (value) => submitted = value)));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('photo-multi-fill-input-cafe'));
    await tester.ensureVisible(field);
    await tester.tap(find.byKey(const Key('photo-multi-fill-cafe-0')));
    await tester.pump();
    final input = tester.widget<TextField>(field);
    expect(input.focusNode!.hasFocus, isTrue);
    for (final text in ['c', 'ca', 'caf', 'cafe\u0301']) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: 0, end: text.length)));
      await tester.pump();
      expect(input.focusNode!.hasFocus, isTrue);
      expect(input.controller!.text, text);
    }
    await tester.enterText(field, 'café');
    await tester.enterText(field, 'caf'); // Backspace edits the same input.
    await tester.pump();
    expect(
        tester
            .widget<StickerButton>(
                find.byKey(const Key('photo-multi-fill-submit')))
            .onPressed,
        isNull);
    await tester.enterText(field, 'café');
    await tester.pump();
    final submit = find.byKey(const Key('photo-multi-fill-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    expect(submitted, {'cafe': 'café'});
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

LessonMasteryItem _item(String id, String answer, double x) =>
    LessonMasteryItem(
      id: id,
      photoNoteId: 'photo-1',
      mediaAssetId: 'media-1',
      imageRelativePath: 'capy_scans/photo.jpg',
      imageWidth: 100,
      imageHeight: 100,
      targetId: 'target-$id',
      boundingBox: LessonNormalizedBoundingBox(
        x: x,
        y: 0.1,
        width: 0.2,
        height: 0.2,
      ),
      answer: answer,
      sourceRevision: 'revision-$id',
    );

final class _MemoryMediaLoader implements LibraryMediaLoader {
  const _MemoryMediaLoader();

  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<Uint8List> readBytes(String relativePath) async => _png;

  @override
  Future<int> sizeBytes(String relativePath) async => _png.length;
}
