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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          .widget<FilledButton>(find.byKey(const Key('photo-order-submit')))
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
