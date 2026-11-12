import 'dart:convert';

import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_album_image_picker.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/normalized_bounding_box.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
const _noteId = '20000000-0000-4000-8000-000000000001';
const _mediaId = '30000000-0000-4000-8000-000000000001';
const _scanId = '40000000-0000-4000-8000-000000000001';
const _detectionId = '50000000-0000-4000-8000-000000000001';
const _path = 'capy_scans/library-photo.png';

void main() {
  final createdAt = DateTime.utc(2026, 9, 29);
  final note = PhotoNote(
    id: _noteId,
    userId: _userId,
    mediaAssetId: _mediaId,
    title: 'Ảnh trong tab Ảnh',
    templateId: 'standard',
    primaryScanRunId: _scanId,
    createdAt: createdAt,
    updatedAt: createdAt,
    syncStatus: SyncStatus.localOnly,
  );
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  final snapshot = PhotoNoteSnapshot(
    photoNote: note,
    mediaAsset: MediaAsset(
      id: _mediaId,
      userId: _userId,
      contentHashSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      displayRelativePath: _path,
      mimeType: 'image/png',
      width: 1,
      height: 1,
      orientation: 0,
      byteSizeDisplay: bytes.length,
      preprocessingVersion: 'test-v1',
      captureSource: CaptureSource.camera,
      createdAt: createdAt,
      syncStatus: SyncStatus.localOnly,
    ),
    primaryScanRun: ScanRun(
      id: _scanId,
      userId: _userId,
      mediaAssetId: _mediaId,
      requestId: 'picker-test',
      provider: 'test',
      modelName: 'test',
      promptVersion: 'test',
      responseSchemaVersion: 'test',
      preprocessingVersion: 'test',
      rawResponseJson: const {'words': []},
      responseHashSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      status: ScanRunStatus.succeeded,
      startedAt: createdAt,
      completedAt: createdAt,
    ),
    detections: [
      VocabDetection(
        id: _detectionId,
        scanRunId: _scanId,
        wordRaw: 'tea',
        wordNormalized: 'tea',
        phonetic: '/tiː/',
        meaningVi: 'trà',
        partOfSpeech: 'noun',
        boundingBox: NormalizedBoundingBox(
          x: .1,
          y: .2,
          width: .3,
          height: .2,
        ),
        displayOrder: 0,
        createdAt: createdAt,
      ),
    ],
    annotations: const [],
  );

  testWidgets('shows all Library photos when the user has no Album',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    OperationalChatAlbumImageSelection? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryAlbumsProvider.overrideWith((_) => Stream.value(const [])),
          libraryPhotoNotesProvider.overrideWith((_) => Stream.value([note])),
          libraryPhotoNoteSnapshotProvider(_noteId)
              .overrideWith((_) async => snapshot),
          libraryMediaBytesProvider(_path).overrideWith((_) async => bytes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showChatAlbumImagePicker(context);
                },
                child: const Text('Mở picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở picker'));
    final overlayFinder = find.byKey(
      const ValueKey('chat-album-labels-$_noteId'),
    );
    for (var attempt = 0;
        attempt < 10 && overlayFinder.evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Chọn một ảnh từ Thư viện'), findsOneWidget);
    expect(find.byKey(const Key('chat-album-picker-close')), findsOneWidget);
    expect(find.text('🖼️ Tất cả ảnh (1)'), findsOneWidget);
    expect(find.text('Ảnh trong tab Ảnh'), findsNothing);
    expect(overlayFinder, findsOneWidget);
    final overlay = tester.widget<VocabCanvasOverlay>(overlayFinder);
    expect(overlay.words, hasLength(1));
    expect(overlay.words.single.word, 'tea');
    expect(overlay.words.single.phonetic, '/tiː/');
    expect(overlay.words.single.meaning, 'trà');
    expect(find.text('Bạn chưa có Album nào để chia sẻ.'), findsNothing);
    expect(tester.takeException(), isNull);

    final shell = tester.widget<Container>(
      find.byKey(const Key('chat-album-picker-shell')),
    );
    final decoration = shell.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, 3);
    expect(decoration.boxShadow!.single.offset, const Offset(0, 8));

    await tester.tap(find.byKey(const ValueKey('chat-album-photo-$_noteId')));
    await tester.pumpAndSettle();

    expect(selected?.photoNoteId, _noteId);
    expect(selected?.localRelativePath, _path);
    expect(selected?.byteSize, bytes.length);
    expect(selected?.labels, hasLength(1));
    expect(selected?.labels.single.word, 'tea');
    expect(selected?.labels.single.phonetic, '/tiː/');
    expect(selected?.labels.single.meaning, 'trà');
  });
}
