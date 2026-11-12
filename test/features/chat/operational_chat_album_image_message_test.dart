import 'dart:convert';

import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_album_image_message.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerId = '10000000-0000-0000-0000-000000000001';
const _conversation = '20000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('deleted Album image keeps bubble and shows required text',
      (tester) async {
    final message = OperationalChatMessage(
      id: '30000000-0000-0000-0000-000000000001',
      conversationId: _conversation,
      senderId: _ownerId,
      rawText: operationalChatAlbumImagePlaceholder,
      sourceLanguageCode: 'vi',
      clientGeneratedId: '40000000-0000-0000-0000-000000000001',
      clientCreatedAt: DateTime.utc(2026, 9, 29),
      sentAt: DateTime.utc(2026, 9, 29),
      sendStatus: ChatSendStatus.sent,
      albumImage: OperationalChatAlbumImage(
        sourcePhotoNoteId: '50000000-0000-0000-0000-000000000001',
        objectPath: '$_ownerId/30000000-0000-0000-0000-000000000001/image.jpg',
        mimeType: 'image/jpeg',
        byteSize: 4,
        available: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: OperationalChatAlbumImageMessage(
              owner: ChatOwner(
                  projectRef: 'ssssssssssssssssssss', userId: _ownerId),
              message: message,
            ),
          ),
        ),
      ),
    );

    expect(find.text(operationalChatUnavailableImageText), findsOneWidget);
    expect(
        find.byKey(const Key('chat-album-image-unavailable')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('equivalent stream rows keep one image load without flashing',
      (tester) async {
    final owner = ChatOwner(
      projectRef: 'ssssssssssssssssssss',
      userId: _ownerId,
    );
    final firstImage = _availableImage();
    final replacementImage = _availableImage();
    final firstMessage = _message(firstImage);
    final replacementMessage = _message(replacementImage);
    var loads = 0;
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationalChatAlbumImageBytesProvider((owner, firstImage))
              .overrideWith((_) async {
            loads++;
            return bytes;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _MessageReplacementHarness(
              owner: owner,
              first: firstMessage,
              replacement: replacementMessage,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(loads, 1);
    expect(find.byKey(const Key('chat-album-image')), findsOneWidget);

    await tester.tap(find.byKey(const Key('replace-chat-image-row')));
    await tester.pump();

    expect(firstImage, replacementImage);
    expect(loads, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('chat-album-image')), findsOneWidget);
  });

  testWidgets('new Album image shows every vocabulary label field by default',
      (tester) async {
    final owner = ChatOwner(
      projectRef: 'ssssssssssssssssssss',
      userId: _ownerId,
    );
    final image = _availableImage(withLabels: true);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationalChatAlbumImageBytesProvider((owner, image))
              .overrideWith((_) async => bytes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OperationalChatAlbumImageMessage(
              owner: owner,
              message: _message(image),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final overlay = tester.widget<VocabCanvasOverlay>(
      find.byType(VocabCanvasOverlay),
    );
    expect(
        find.byKey(const Key('chat-album-image-with-labels')), findsOneWidget);
    expect(overlay.words, hasLength(1));
    expect(overlay.words.single.word, 'tea');
    expect(overlay.showLabels, isTrue);
    expect(overlay.showWord, isTrue);
    expect(overlay.showPhonetic, isTrue);
    expect(overlay.showMeaning, isTrue);
    expect(overlay.fitCanvasToImage, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('chat-album-image-with-labels'))),
      const Size(260, 260),
    );
  });

  testWidgets('zoom action opens a fixed image viewer and closes',
      (tester) async {
    final owner = ChatOwner(
      projectRef: 'ssssssssssssssssssss',
      userId: _ownerId,
    );
    final image = _availableImage(withLabels: true);
    final message = _message(image);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    var zoomed = false;
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationalChatAlbumImageBytesProvider((owner, image))
              .overrideWith((_) async => bytes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 340,
                height: 600,
                child: zoomed
                    ? OperationalChatAlbumImageViewer(
                        owner: owner,
                        message: message,
                        onClose: () => setState(() {
                          closed = true;
                          zoomed = false;
                        }),
                      )
                    : OperationalChatAlbumImageMessage(
                        owner: owner,
                        message: message,
                        onZoom: () => setState(() => zoomed = true),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    final zoomButton = find.byKey(const Key('chat-album-image-zoom'));
    expect(zoomButton, findsOneWidget);
    expect(tester.getSize(zoomButton), const Size(48, 48));
    expect(
      tester.getSize(find.byKey(const Key('chat-album-image-zoom-visual'))),
      const Size(36, 36),
    );
    await tester.tap(zoomButton);
    await tester.pump();

    expect(find.byKey(const Key('chat-album-image-viewer')), findsOneWidget);
    expect(
      find.byKey(const Key('chat-album-image-fixed-viewer')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsNothing);
    final imageCanvas = find.byKey(const Key('chat-album-image-with-labels'));
    final positionBeforeDrag = tester.getTopLeft(imageCanvas);
    final gesture = await tester.startGesture(
      tester.getCenter(imageCanvas),
    );
    await gesture.moveBy(const Offset(60, 40));
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(imageCanvas), positionBeforeDrag);
    await tester.tap(find.byKey(const Key('chat-album-image-viewer-close')));
    await tester.pump();

    expect(closed, isTrue);
    expect(find.byKey(const Key('chat-album-image-viewer')), findsNothing);
  });
}

OperationalChatAlbumImage _availableImage({bool withLabels = false}) =>
    OperationalChatAlbumImage(
      sourcePhotoNoteId: '50000000-0000-0000-0000-000000000001',
      objectPath: '$_ownerId/30000000-0000-0000-0000-000000000001/image.png',
      mimeType: 'image/png',
      byteSize: 68,
      available: true,
      labels: withLabels
          ? [
              OperationalChatImageLabel(
                number: 1,
                word: 'tea',
                phonetic: '/tiː/',
                meaning: 'trà',
                partOfSpeech: 'noun',
                x: .1,
                y: .2,
                width: .3,
                height: .2,
              ),
            ]
          : const [],
      localRelativePath: 'capy_scans/chat-image.png',
    );

OperationalChatMessage _message(OperationalChatAlbumImage image) =>
    OperationalChatMessage(
      id: '30000000-0000-0000-0000-000000000001',
      conversationId: _conversation,
      senderId: _ownerId,
      rawText: operationalChatAlbumImagePlaceholder,
      sourceLanguageCode: 'vi',
      clientGeneratedId: '40000000-0000-0000-0000-000000000001',
      clientCreatedAt: DateTime.utc(2026, 9, 29),
      sentAt: DateTime.utc(2026, 9, 29),
      sendStatus: ChatSendStatus.sent,
      albumImage: image,
    );

class _MessageReplacementHarness extends StatefulWidget {
  const _MessageReplacementHarness({
    required this.owner,
    required this.first,
    required this.replacement,
  });

  final ChatOwner owner;
  final OperationalChatMessage first;
  final OperationalChatMessage replacement;

  @override
  State<_MessageReplacementHarness> createState() =>
      _MessageReplacementHarnessState();
}

class _MessageReplacementHarnessState
    extends State<_MessageReplacementHarness> {
  var replaced = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          OperationalChatAlbumImageMessage(
            owner: widget.owner,
            message: replaced ? widget.replacement : widget.first,
          ),
          TextButton(
            key: const Key('replace-chat-image-row'),
            onPressed: () => setState(() => replaced = true),
            child: const Text('Replace row'),
          ),
        ],
      );
}
