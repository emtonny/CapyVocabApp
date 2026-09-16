import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/application/library_media_recovery_service.dart';
import 'package:capy_vocab/features/library/application/library_cloud_media_restore_service.dart';
import 'package:capy_vocab/features/library/domain/entities/album_models.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/normalized_bounding_box.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:capy_vocab/features/library/domain/repositories/album_repository.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_cloud_media_restore_provider.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_media_integrity_provider.dart';
import 'package:capy_vocab/features/library/presentation/screens/storage_album_screen.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
const _firstNoteId = '40000000-0000-4000-8000-000000000001';
const _secondNoteId = '40000000-0000-4000-8000-000000000002';
const _thirdNoteId = '40000000-0000-4000-8000-000000000003';
const _firstAlbumId = '60000000-0000-4000-8000-000000000001';
const _secondAlbumId = '60000000-0000-4000-8000-000000000002';
final _createdAt = DateTime.utc(2026, 9, 6, 1, 7);

void main() {
  testWidgets('lists saved notes from the offline repository and opens one',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.synced,
      detectionCount: 2,
    );
    final second = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Window',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );
    final repository = _FakeLibraryRepository(
      notes: [first.photoNote, second.photoNote],
      snapshots: {
        first.photoNote.id: first,
        second.photoNote.id: second,
      },
    );
    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    expect(find.byKey(const Key('library-photo-note-list')), findsOneWidget);
    expect(find.text('Thư viện ảnh'), findsOneWidget);
    expect(find.text('2 từ'), findsOneWidget);
    expect(find.text('1 từ'), findsOneWidget);
    expect(find.text('Cup, table'), findsNothing);
    expect(find.text('Window'), findsNothing);
    expect(find.text('word 1'), findsNothing);
    expect(find.text('word 2'), findsNothing);
    expect(
      find.byKey(
        const Key('library-storage-summary'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final photoTabSurface = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('library-photos-tab')),
            matching: find.byType(Container),
          )
          .first,
    );
    final photoTabDecoration = photoTabSurface.decoration! as BoxDecoration;
    expect(photoTabDecoration.color, AppColors.yellow);
    expect(
      (photoTabDecoration.border! as Border).top.width,
      closeTo(2.4, 0.01),
    );
    expect(
      find.textContaining(
        '2/2 ảnh trên máy • 136 B',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-note-menu-$_firstNoteId')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('library-select-all-photos-button')),
      ),
      const Size(120, 48),
    );
    expect(
      tester.getSize(find.byKey(const Key('library-date-filter-button'))),
      const Size(120, 48),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('library-select-all-photos-button')),
          )
          .dy,
      greaterThan(tester.getBottomLeft(find.text('Tất cả ảnh (2)')).dy),
    );

    final firstCard = tester.getSize(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    expect(firstCard.height, closeTo(firstCard.width + 52, 0.1));
    expect(
      tester
          .getSize(find.byKey(const Key('library-note-menu-$_firstNoteId')))
          .height,
      48,
    );
    await tester.tap(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    await tester.pumpAndSettle();

    final selectedPhotoCard = tester.widget<Container>(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    final selectedPhotoDecoration =
        selectedPhotoCard.decoration! as BoxDecoration;
    expect(selectedPhotoDecoration.color, AppColors.yellow);
    expect(
      (selectedPhotoDecoration.border! as Border).top.width,
      closeTo(2.4, 0.01),
    );
    expect(selectedPhotoCard.padding, const EdgeInsets.all(3.5));

    expect(
      find.byKey(const Key('library-view-selected-vocabulary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-add-selected-photos-to-album')),
      findsOneWidget,
    );
    expect(find.text('Xem từ vựng (1)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const Key('library-view-selected-vocabulary')))
          .bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('bottom-nav-shell'))).top,
      ),
    );
    expect(
      tester
          .getRect(find.byKey(const Key('library-photo-note-$_firstNoteId')))
          .bottom,
      lessThanOrEqualTo(
        tester
            .getRect(
              find.byKey(const Key('library-photo-selection-action-bar')),
            )
            .top,
      ),
    );

    await tester.tap(
      find.byKey(const Key('library-view-selected-vocabulary')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('library-selected-vocabulary-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-selected-vocabulary-card-$_firstNoteId')),
      findsOneWidget,
    );
    expect(find.text('word 1'), findsNothing);

    await tester.tap(
      find.byKey(const Key('library-selected-vocabulary-toggle-$_firstNoteId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_firstNoteId')),
      findsOneWidget,
    );
    expect(find.text('word 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('library-selected-vocabulary-toggle-$_firstNoteId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_firstNoteId')),
      findsNothing,
    );
  });

  testWidgets('keeps selected photo order and toggles vocabulary independently',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshots = [
      _snapshot(
        noteId: _firstNoteId,
        suffix: '1',
        title: 'First',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 2,
      ),
      _snapshot(
        noteId: _secondNoteId,
        suffix: '2',
        title: 'Second',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 1,
      ),
    ];

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: snapshots.map((snapshot) => snapshot.photoNote).toList(),
        snapshots: {
          for (final snapshot in snapshots) snapshot.photoNote.id: snapshot,
        },
      ),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(
      find.byKey(const Key('library-photo-note-$_secondNoteId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xem từ vựng (2)'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('library-view-selected-vocabulary')),
    );
    await tester.pumpAndSettle();

    final secondCard = find.byKey(
      const Key('library-selected-vocabulary-card-$_secondNoteId'),
    );
    final firstCard = find.byKey(
      const Key('library-selected-vocabulary-card-$_firstNoteId'),
    );
    expect(tester.getTopLeft(secondCard).dy,
        lessThan(tester.getTopLeft(firstCard).dy));
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_secondNoteId')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_firstNoteId')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
          const Key('library-selected-vocabulary-toggle-$_secondNoteId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_secondNoteId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_firstNoteId')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
          const Key('library-selected-vocabulary-toggle-$_secondNoteId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-selected-vocabulary-words-$_secondNoteId')),
      findsNothing,
    );
  });

  testWidgets(
      'saved vocabulary labels start hidden and use the scan visibility logic',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'First',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {_firstNoteId: snapshot},
      ),
      loader: _FakeMediaLoader(),
      screen: SelectedPhotoVocabularyScreen(notes: [snapshot.photoNote]),
    );
    expect(
      tester
          .getSize(
            find.byKey(const Key('library-selected-vocabulary-header')),
          )
          .height,
      greaterThanOrEqualTo(68),
    );
    expect(
      tester.getSize(
        find.byKey(const Key('library-selected-vocabulary-back')),
      ),
      const Size.square(48),
    );
    final headerDecoration = tester
        .widget<Container>(
          find.byKey(const Key('library-selected-vocabulary-header')),
        )
        .decoration! as BoxDecoration;
    expect(headerDecoration.border!.top.width, 2.5);
    expect(headerDecoration.boxShadow, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byKey(const Key('library-selected-vocabulary-toggle-$_firstNoteId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('HIỆN LABEL'), findsOneWidget);
    expect(find.text('TỪ VỰNG'), findsOneWidget);
    expect(find.text('PHIÊN ÂM'), findsOneWidget);
    expect(find.text('DỊCH'), findsOneWidget);
    expect(
      find.byKey(const Key('library-media-overlay-capy_scans/scan_1.jpg')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('library-toggle-word-$_firstNoteId')),
    );
    await tester.pump();
    var overlay = tester.widget<VocabCanvasOverlay>(
      find.byKey(const Key('library-media-overlay-capy_scans/scan_1.jpg')),
    );
    expect(overlay.showLabels, isTrue);
    expect(overlay.showWord, isTrue);
    expect(overlay.showPhonetic, isFalse);
    expect(overlay.showMeaning, isFalse);

    await tester.tap(
      find.byKey(const Key('library-toggle-phonetic-$_firstNoteId')),
    );
    await tester.tap(
      find.byKey(const Key('library-toggle-meaning-$_firstNoteId')),
    );
    await tester.pump();
    overlay = tester.widget<VocabCanvasOverlay>(
      find.byKey(const Key('library-media-overlay-capy_scans/scan_1.jpg')),
    );
    expect(overlay.showWord, isTrue);
    expect(overlay.showPhonetic, isTrue);
    expect(overlay.showMeaning, isTrue);

    await tester.tap(
      find.byKey(const Key('library-toggle-labels-$_firstNoteId')),
    );
    await tester.pump();
    expect(find.text('HIỆN LABEL'), findsOneWidget);
    expect(
      find.byKey(const Key('library-media-overlay-capy_scans/scan_1.jpg')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('library-toggle-labels-$_firstNoteId')),
    );
    await tester.pump();
    overlay = tester.widget<VocabCanvasOverlay>(
      find.byKey(const Key('library-media-overlay-capy_scans/scan_1.jpg')),
    );
    expect(find.text('ẨN LABEL'), findsOneWidget);
    expect(overlay.showLabels, isTrue);
    expect(overlay.showWord, isTrue);
    expect(overlay.showPhonetic, isTrue);
    expect(overlay.showMeaning, isTrue);
  });

  testWidgets(
      'shows the full final card before a dynamically measured photo action bar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snapshots = [
      _snapshot(
        noteId: _firstNoteId,
        suffix: '1',
        title: 'First',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 2,
      ),
      _snapshot(
        noteId: _secondNoteId,
        suffix: '2',
        title: 'Second',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 2,
      ),
      _snapshot(
        noteId: _thirdNoteId,
        suffix: '3',
        title: 'Third',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 2,
      ),
    ];

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: snapshots.map((snapshot) => snapshot.photoNote).toList(),
        snapshots: {
          for (final snapshot in snapshots) snapshot.photoNote.id: snapshot,
        },
      ),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-photo-note-$_firstNoteId')));
    await tester.pumpAndSettle();

    final pageScrollFinder = find.byKey(const Key('library-page-scroll'));
    final switcherTopBefore =
        tester.getTopLeft(find.byKey(const Key('library-subview-switcher'))).dy;
    final bottomNavTopBefore =
        tester.getTopLeft(find.byKey(const Key('bottom-nav-shell'))).dy;

    await tester.drag(pageScrollFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('library-subview-switcher'))).dy,
      lessThan(switcherTopBefore),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('bottom-nav-shell'))).dy,
      closeTo(bottomNavTopBefore, 0.5),
    );

    final actionBarRect = tester.getRect(
      find.byKey(const Key('library-photo-selection-action-bar')),
    );
    final finalCardRect = tester.getRect(
      find.byKey(const Key('library-photo-note-$_thirdNoteId')),
    );

    expect(finalCardRect.bottom, lessThanOrEqualTo(actionBarRect.top));
    expect(
      actionBarRect.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('bottom-nav-shell'))).top,
      ),
    );
  });

  testWidgets('immediately adds a selected photo after choosing an Album',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 2,
    );
    final album = _album(name: 'Đồ vật quanh mình', icon: '📚');
    final albumRepository = _FakeAlbumRepository(albums: [album]);
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {snapshot.photoNote.id: snapshot},
      ),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-photo-note-$_firstNoteId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-add-selected-photos-to-album')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('library-select-album-${album.id}')));
    await tester.pumpAndSettle();

    expect(albumRepository.addedPhotoNoteIds, [_firstNoteId]);
    expect(
      find.byKey(const Key('library-album-assignment-banner')),
      findsNothing,
    );
    expect(find.byKey(const Key('library-album-photo-list')), findsOneWidget);
    expect(find.text('Đã thêm 1 ảnh vào Đồ vật quanh mình.'), findsOneWidget);
  });

  testWidgets('creates a new Album from the selected photo action bar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 2,
    );
    final albumRepository = _FakeAlbumRepository(albums: const []);
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {snapshot.photoNote.id: snapshot},
      ),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-add-selected-photos-to-album')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-create-album-from-selected-photos')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library-album-name-field')),
      'Study set',
    );
    await tester.tap(find.byKey(const Key('library-create-album-confirm')));
    await tester.pumpAndSettle();

    expect(albumRepository.albums, hasLength(1));
    expect(albumRepository.albums.single.name, 'Study set');
    expect(albumRepository.addedPhotoNoteIds, [_firstNoteId]);
    expect(find.byKey(const Key('library-album-photo-list')), findsOneWidget);
  });

  testWidgets(
      'does not create an Album when its initial Photo Note assignment fails',
      (tester) async {
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 2,
    );
    final albumRepository = _FakeAlbumRepository(
      albums: const [],
      failCreateAlbumWithPhotoNotes: true,
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {snapshot.photoNote.id: snapshot},
      ),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-add-selected-photos-to-album')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-create-album-from-selected-photos')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library-album-name-field')),
      'Study set',
    );
    await tester.tap(find.byKey(const Key('library-create-album-confirm')));
    await tester.pumpAndSettle();

    expect(albumRepository.albums, isEmpty);
    expect(albumRepository.addedPhotoNoteIds, isEmpty);
    expect(find.text('Không thể tạo Album.'), findsOneWidget);
    expect(
      find.byKey(const Key('library-photo-selection-action-bar')),
      findsOneWidget,
    );
    expect(find.text('Xem từ vựng (1)'), findsOneWidget);
  });

  testWidgets('opens Album and assigns selected Photo Notes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 2,
    );
    final libraryRepository = _FakeLibraryRepository(
      notes: [snapshot.photoNote],
      snapshots: {snapshot.photoNote.id: snapshot},
    );
    final albumRepository = _FakeAlbumRepository(
      albums: [_album(name: 'Đồ vật quanh mình', icon: '📚')],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: libraryRepository,
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-album-grid')), findsOneWidget);
    final albumGrid = tester.widget<SliverGrid>(
      find.byKey(const Key('library-album-grid')),
    );
    expect(
      (albumGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    tester.view.physicalSize = const Size(320, 800);
    await tester.pumpAndSettle();
    final narrowAlbumGrid = tester.widget<SliverGrid>(
      find.byKey(const Key('library-album-grid')),
    );
    expect(
      (narrowAlbumGrid.gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    expect(find.text('Đồ vật quanh mình'), findsOneWidget);
    final favoriteButton = tester.widget<StickerButton>(
      find.byKey(const Key('library-album-favorite-$_firstAlbumId')),
    );
    expect(favoriteButton.showShadow, isFalse);
    expect(
      favoriteButton.borderColor,
      Colors.transparent,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('library-album-favorite-$_firstAlbumId')),
      ),
      const Size.square(48),
    );
    expect(
      tester.getSize(
        find.byKey(const Key('library-album-menu-$_firstAlbumId')),
      ),
      const Size.square(48),
    );

    await tester.tap(
      find.byKey(const Key('library-album-favorite-$_firstAlbumId')),
    );
    await tester.pumpAndSettle();
    expect(albumRepository.albums.single.isFavorite, isTrue);

    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-album-detail-back')), findsOneWidget);
    expect(find.text('Tất cả Album'), findsOneWidget);
    expect(find.text('Đồ vật quanh mình'), findsOneWidget);
    expect(find.byKey(const Key('library-album-add-photos')), findsOneWidget);
    expect(find.text('+ Thêm ảnh'), findsOneWidget);
    final albumTitleBox = tester.widget<Container>(
      find.byKey(const Key('library-album-detail-title')),
    );
    final albumTitleDecoration = albumTitleBox.decoration! as BoxDecoration;
    expect(albumTitleDecoration.color, Colors.white);
    expect(albumTitleDecoration.border!.top.width, 2.2);
    expect(albumTitleDecoration.boxShadow, isNotEmpty);
    expect(
      tester
          .getSize(find.byKey(const Key('library-album-detail-title')))
          .height,
      60,
    );
    expect(
      tester.getSize(find.byKey(const Key('library-album-detail-back'))),
      const Size(120, 48),
    );
    expect(
      tester.getSize(find.byKey(const Key('library-album-add-photos'))),
      const Size(120, 48),
    );

    await tester.tap(find.byKey(const Key('library-album-add-photos')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-album-assignment-banner')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('library-photo-note-$_firstNoteId')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('library-album-assignment-confirm')),
    );
    await tester.pumpAndSettle();

    expect(albumRepository.addedPhotoNoteIds, [_firstNoteId]);
    expect(find.text('Đã thêm 1 ảnh vào Đồ vật quanh mình.'), findsOneWidget);
  });

  testWidgets('creates and deletes an Album without deleting Photo Notes',
      (tester) async {
    final albumRepository = _FakeAlbumRepository(albums: const []);
    addTearDown(albumRepository.dispose);
    final libraryRepository = _FakeLibraryRepository(
      notes: const [],
      snapshots: const {},
    );

    await _pumpLibrary(
      tester,
      repository: libraryRepository,
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-albums-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-create-album')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-album-icon-🦫')), findsOneWidget);
    expect(find.byKey(const Key('library-album-icon-🦌')), findsOneWidget);
    expect(find.byKey(const Key('library-album-open-emoji-picker')),
        findsOneWidget);
    expect(find.byKey(const Key('library-album-more-stickers-button')),
        findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('library-album-name-field')),
      'Món ăn',
    );
    await tester.tap(find.byKey(const Key('library-album-icon-🍜')));
    await tester.tap(find.byKey(const Key('library-create-album-confirm')));
    await tester.pumpAndSettle();

    expect(albumRepository.albums.single.name, 'Món ăn');
    expect(albumRepository.albums.single.icon, '🍜');
    expect(find.text('Món ăn'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('library-album-start-selection'))),
      const Size(120, 48),
    );
    expect(
      tester.getSize(find.byKey(const Key('library-create-album'))),
      const Size(120, 48),
    );

    final createdId = albumRepository.albums.single.id;
    await tester.tap(find.byKey(Key('library-album-menu-$createdId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa Album'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-delete-album-confirm')));
    await tester.pumpAndSettle();

    expect(albumRepository.albums, isEmpty);
    expect(libraryRepository.notes, isEmpty);
  });

  testWidgets(
      'opens unique vocabulary photos from every selected Album in Album order',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshots = [
      _snapshot(
        noteId: _firstNoteId,
        suffix: '1',
        title: 'First',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 1,
      ),
      _snapshot(
        noteId: _secondNoteId,
        suffix: '2',
        title: 'Second',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 1,
      ),
      _snapshot(
        noteId: _thirdNoteId,
        suffix: '3',
        title: 'Third',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 1,
      ),
    ];
    final libraryRepository = _FakeLibraryRepository(
      notes: snapshots.map((snapshot) => snapshot.photoNote).toList(),
      snapshots: {
        for (final snapshot in snapshots) snapshot.photoNote.id: snapshot,
      },
      albumPhotoNoteIds: const {
        _firstAlbumId: [_firstNoteId, _secondNoteId],
        _secondAlbumId: [_secondNoteId, _thirdNoteId],
      },
    );
    final albumRepository = _FakeAlbumRepository(
      albums: [
        _album(
          id: _firstAlbumId,
          name: 'Góc học tập',
          icon: '📚',
          isFavorite: true,
        ),
        _album(id: _secondAlbumId, name: 'Thiên nhiên', icon: '🌲'),
      ],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: libraryRepository,
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-start-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_secondAlbumId')));
    await tester.pumpAndSettle();

    expect(find.text('Xem từ vựng (2 Album)'), findsOneWidget);
    final viewButton =
        find.byKey(const Key('library-view-selected-album-vocabulary'));
    expect(viewButton, findsOneWidget);
    expect(
      tester.getRect(viewButton).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('bottom-nav-shell'))).top,
      ),
    );

    await tester.tap(viewButton);
    await tester.pumpAndSettle();

    final firstCard = find.byKey(
      const Key('library-selected-vocabulary-card-$_firstNoteId'),
    );
    final secondCard = find.byKey(
      const Key('library-selected-vocabulary-card-$_secondNoteId'),
    );
    final thirdCard = find.byKey(
      const Key('library-selected-vocabulary-card-$_thirdNoteId'),
    );
    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);
    expect(thirdCard, findsOneWidget);
    expect(tester.getTopLeft(firstCard).dy,
        lessThan(tester.getTopLeft(secondCard).dy));
    expect(tester.getTopLeft(secondCard).dy,
        lessThan(tester.getTopLeft(thirdCard).dy));
  });

  testWidgets('Album selection toggle clears every selected Album',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final albumRepository = _FakeAlbumRepository(
      albums: [
        _album(id: _firstAlbumId, name: 'Góc học tập', icon: '📚'),
        _album(id: _secondAlbumId, name: 'Thiên nhiên', icon: '🌲'),
      ],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(notes: const [], snapshots: const {}),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('library-album-start-selection'));
    expect(find.text('Chọn Album'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Bỏ chọn Album'), findsOneWidget);
    expect(find.byKey(const Key('library-album-select-all')), findsNothing);
    expect(find.byKey(const Key('library-create-album')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    expect(find.text('1 Album đã chọn'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Chọn Album'), findsOneWidget);
    expect(find.text('1 Album đã chọn'), findsNothing);
    expect(find.byKey(const Key('library-album-select-all')), findsNothing);
    expect(find.byKey(const Key('library-create-album')), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('0 Album đã chọn'), findsOneWidget);
  });

  testWidgets('keeps Album selection when selected Albums have no photos',
      (tester) async {
    final albumRepository = _FakeAlbumRepository(
      albums: [_album(name: 'Album trống', icon: '📁')],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: const [],
        snapshots: const {},
        albumPhotoNoteIds: const {_firstAlbumId: []},
      ),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-start-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-view-selected-album-vocabulary')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Các Album đã chọn chưa có ảnh để xem từ vựng.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-album-selection-action-bar')),
      findsOneWidget,
    );
    expect(find.text('1 Album đã chọn'), findsOneWidget);
  });

  testWidgets('keeps Album selection when Album vocabulary loading fails',
      (tester) async {
    final albumRepository = _FakeAlbumRepository(
      albums: [_album(name: 'Album lỗi', icon: '📁')],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: const [],
        snapshots: const {},
        failAlbumPhotoNoteQuery: true,
      ),
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-start-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-view-selected-album-vocabulary')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể mở từ vựng của các Album đã chọn.'),
      findsOneWidget,
    );
    expect(find.text('1 Album đã chọn'), findsOneWidget);
  });

  testWidgets(
      'selects and deletes multiple Albums without deleting Photo Notes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );
    final libraryRepository = _FakeLibraryRepository(
      notes: [snapshot.photoNote],
      snapshots: {snapshot.photoNote.id: snapshot},
    );
    final albumRepository = _FakeAlbumRepository(
      albums: [
        _album(id: _firstAlbumId, name: 'Đồ dùng', icon: '📚'),
        _album(id: _secondAlbumId, name: 'Đồ ăn', icon: '🍜'),
      ],
    );
    addTearDown(albumRepository.dispose);

    await _pumpLibrary(
      tester,
      repository: libraryRepository,
      albumRepository: albumRepository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn Album'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-album-start-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_firstAlbumId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-album-$_secondAlbumId')));
    await tester.pumpAndSettle();

    expect(find.text('2 Album đã chọn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-delete-selected-albums')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-delete-album-confirm')));
    await tester.pumpAndSettle();

    expect(albumRepository.albums, isEmpty);
    expect(libraryRepository.notes, hasLength(1));
    expect(find.byKey(const Key('library-albums-empty')), findsOneWidget);
  });

  testWidgets(
      'counts only real local files and labels cloud-only versus missing',
      (tester) async {
    final local = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Local',
      syncStatus: SyncStatus.synced,
      detectionCount: 1,
    );
    final cloud = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Cloud',
      syncStatus: SyncStatus.synced,
      detectionCount: 1,
      remoteDisplayPath: '$_userId/media/cloud.jpg',
    );
    final missing = _snapshot(
      noteId: _thirdNoteId,
      suffix: '3',
      title: 'Missing',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );
    final missingPaths = {
      cloud.mediaAsset.displayRelativePath,
      missing.mediaAsset.displayRelativePath,
    };

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [local.photoNote, cloud.photoNote, missing.photoNote],
        snapshots: {
          local.photoNote.id: local,
          cloud.photoNote.id: cloud,
          missing.photoNote.id: missing,
        },
      ),
      loader: _FakeMediaLoader(missingPaths: missingPaths),
      screen: const StorageAlbumScreen(),
    );

    expect(find.text('Thư viện ảnh'), findsOneWidget);
    expect(
      find.textContaining(
        '1/3 ảnh trên máy • 68 B',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '1 trên cloud\n1 bị thiếu',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('moves a saved note to the 30-day Trash after confirmation',
      (tester) async {
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );
    final repository = _FakeLibraryRepository(
      notes: [snapshot.photoNote],
      snapshots: {snapshot.photoNote.id: snapshot},
    );

    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester
        .tap(find.byKey(Key('library-note-menu-${snapshot.photoNote.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Chuyển bài vào thùng rác?'), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('library-trash-confirm-action')),
    );
    await tester.pumpAndSettle();

    expect(repository.notes.single.deletedAt, isNotNull);
    expect(find.byKey(Key('library-photo-note-${snapshot.photoNote.id}')),
        findsNothing);
  });

  testWidgets('date filters apply to both Photos and Trash', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final localNow = DateTime.now();
    final today = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      12,
    ).toUtc();
    final old = today.subtract(const Duration(days: 10));
    final todayPhoto = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Today photo',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      createdAt: today,
    );
    final oldPhoto = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Old photo',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      createdAt: old,
    );
    final todayTrash = _snapshot(
      noteId: _thirdNoteId,
      suffix: '3',
      title: 'Today trash',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      createdAt: old,
      deletedAt: today,
    );
    final oldTrash = _snapshot(
      noteId: '40000000-0000-4000-8000-000000000004',
      suffix: '4',
      title: 'Old trash',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      createdAt: old,
      deletedAt: old,
    );
    final snapshots = [todayPhoto, oldPhoto, todayTrash, oldTrash];
    final repository = _FakeLibraryRepository(
      notes: snapshots.map((item) => item.photoNote).toList(),
      snapshots: {for (final item in snapshots) item.photoNote.id: item},
    );

    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    await tester.tap(find.text('Lọc ngày'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-date-filter-dialog')), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    final allPresetButton = tester.widget<StickerButton>(
      find.byKey(const Key('library-date-filter-all')),
    );
    expect(allPresetButton.surfaceColor, AppColors.duoOrange);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('7 ngày qua'), findsOneWidget);
    expect(find.text('1 tháng qua'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-date-filter-today')));
    await tester.tap(find.byKey(const Key('library-date-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-photo-note-$_secondNoteId')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('library-trash-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-date-filter-today')));
    await tester.tap(find.byKey(const Key('library-date-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-trash-note-$_thirdNoteId')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'library-trash-note-40000000-0000-4000-8000-000000000004',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('Trash restores a note and queues explicit permanent deletion',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final restoreSnapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Restore me',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    final deleteSnapshot = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Delete me',
      syncStatus: SyncStatus.synced,
      detectionCount: 1,
      deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
    );
    final repository = _FakeLibraryRepository(
      notes: [restoreSnapshot.photoNote, deleteSnapshot.photoNote],
      snapshots: {
        restoreSnapshot.photoNote.id: restoreSnapshot,
        deleteSnapshot.photoNote.id: deleteSnapshot,
      },
    );

    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: const LibraryTrashScreen(),
      location: '/storage/trash',
    );

    expect(find.byKey(const Key('library-trash-list')), findsOneWidget);
    final trashGrid = tester.widget<GridView>(
      find.byKey(const Key('library-trash-list')),
    );
    expect(
      (trashGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    expect(find.textContaining('Còn '), findsNWidgets(2));
    expect(find.textContaining('Đã xóa '), findsNWidgets(2));
    expect(find.text('Restore me'), findsNothing);
    expect(find.text('Delete me'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(
          Key('library-trash-note-${restoreSnapshot.photoNote.id}'),
        ),
        matching: find.byKey(
          Key('library-trash-restore-${restoreSnapshot.photoNote.id}'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              Key('library-trash-restore-${restoreSnapshot.photoNote.id}'),
            ),
          )
          .height,
      48,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              Key('library-trash-restore-${restoreSnapshot.photoNote.id}'),
            ),
          )
          .width,
      greaterThan(30),
    );
    final restoreButton = tester.widget<StickerButton>(
      find.byKey(Key(
        'library-trash-restore-${restoreSnapshot.photoNote.id}',
      )),
    );
    final deleteButton = tester.widget<StickerButton>(
      find.byKey(Key(
        'library-trash-delete-${deleteSnapshot.photoNote.id}',
      )),
    );
    expect(restoreButton.surfaceColor, const Color(0xFFEAF9DF));
    expect(deleteButton.surfaceColor, const Color(0xFFFFECEB));
    expect(restoreButton.textColor, AppColors.ink);
    expect(deleteButton.textColor, AppColors.ink);
    expect(restoreButton.flat, isTrue);
    expect(deleteButton.flat, isTrue);
    expect(restoreButton.radius, deleteButton.radius);
    expect(restoreButton.padding, deleteButton.padding);
    expect(
      tester.getSize(
        find.byKey(
          Key('library-trash-restore-${restoreSnapshot.photoNote.id}'),
        ),
      ),
      tester.getSize(
        find.byKey(
          Key('library-trash-delete-${deleteSnapshot.photoNote.id}'),
        ),
      ),
    );
    expect(find.text('Khôi phục'), findsNWidgets(2));
    expect(find.text('Xóa vĩnh viễn'), findsNWidgets(2));
    final trashCardRect = tester.getRect(
      find.byKey(Key('library-trash-note-${restoreSnapshot.photoNote.id}')),
    );
    final deleteCardRect = tester.getRect(
      find.byKey(Key('library-trash-note-${deleteSnapshot.photoNote.id}')),
    );
    final restoreRect = tester.getRect(
      find.byKey(Key('library-trash-restore-${restoreSnapshot.photoNote.id}')),
    );
    final deleteRect = tester.getRect(
      find.byKey(Key('library-trash-delete-${deleteSnapshot.photoNote.id}')),
    );
    final daysLeftRect = tester.getRect(
      find.byKey(
        Key('library-trash-days-left-${restoreSnapshot.photoNote.id}'),
      ),
    );
    final deletedAtRect = tester.getRect(
      find.byKey(
        Key('library-trash-deleted-at-${restoreSnapshot.photoNote.id}'),
      ),
    );
    expect(daysLeftRect.center.dy, closeTo(deletedAtRect.center.dy, 0.1));
    expect(deletedAtRect.right, closeTo(trashCardRect.right - 7, 0.1));
    expect(restoreRect.left, closeTo(trashCardRect.left + 7, 0.1));
    expect(deleteRect.right, closeTo(deleteCardRect.right - 7, 0.1));
    expect(restoreRect.bottom, closeTo(deleteRect.bottom, 0.1));
    expect(find.byIcon(Icons.restore_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_forever_rounded), findsNWidgets(2));

    tester.view.physicalSize = const Size(566, 800);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-trash-list')), findsOneWidget);
    final resizedTrashGrid = tester.widget<GridView>(
      find.byKey(const Key('library-trash-list')),
    );
    expect(
      (resizedTrashGrid.gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );

    await tester.tap(
      find.byKey(Key('library-trash-restore-${restoreSnapshot.photoNote.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khôi phục ảnh?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('library-restore-confirm-action')),
    );
    await tester.pumpAndSettle();
    expect(repository.notes.first.deletedAt, isNull);

    await tester.tap(
      find.byKey(Key('library-trash-delete-${deleteSnapshot.photoNote.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu xóa vĩnh viễn?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('library-permanent-delete-confirm-action')),
    );
    await tester.pumpAndSettle();

    expect(
        repository.permanentDeletionIds, contains(deleteSnapshot.photoNote.id));
    expect(
      find.byKey(Key('library-trash-note-${deleteSnapshot.photoNote.id}')),
      findsNothing,
    );
  });

  testWidgets('shows an offline-first empty state', (tester) async {
    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(notes: const [], snapshots: const {}),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    expect(find.byKey(const Key('library-empty-state')), findsOneWidget);
    expect(find.text('Chưa có bài quét nào'), findsOneWidget);
    expect(find.text('Quét ảnh đầu tiên'), findsOneWidget);
    expect(find.text('Thư viện ảnh'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('220'), findsNothing);
    expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    expect(find.byIcon(Icons.settings_rounded), findsNothing);
  });

  testWidgets('opens saved image and vocabulary without a network dependency',
      (tester) async {
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.synced,
      detectionCount: 2,
    );
    final repository = _FakeLibraryRepository(
      notes: [snapshot.photoNote],
      snapshots: {snapshot.photoNote.id: snapshot},
    );

    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: LibraryPhotoNoteDetailScreen(photoNoteId: snapshot.photoNote.id),
      location: '/storage/${snapshot.photoNote.id}',
    );

    expect(find.byKey(const Key('library-photo-note-detail')), findsOneWidget);
    expect(
      find.byKey(const Key('library-media-capy_scans/scan_1.jpg')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('library-photo-note-detail')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cup, table'), findsOneWidget);
    expect(find.text('word 1'), findsOneWidget);
    expect(find.text('nghĩa 1'), findsOneWidget);
    expect(find.text('word 2'), findsOneWidget);
    expect(
      find.text(
        'Ảnh và từ vựng này được đọc từ bộ nhớ trên máy, không cần mạng.',
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('library-photo-note-detail')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nguồn nhận diện: gemini-test'), findsOneWidget);
    expect(repository.snapshotReadCount, greaterThanOrEqualTo(1));
  });

  testWidgets('keeps vocabulary visible when the local image is missing',
      (tester) async {
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {snapshot.photoNote.id: snapshot},
      ),
      loader: _FakeMediaLoader(fail: true),
      screen: LibraryPhotoNoteDetailScreen(photoNoteId: snapshot.photoNote.id),
      location: '/storage/${snapshot.photoNote.id}',
    );

    expect(find.text('Không tìm thấy ảnh local'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('library-photo-note-detail')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('word 1'), findsOneWidget);
    expect(find.text('nghĩa 1'), findsOneWidget);
    expect(
      find.text(
        'Từ vựng đã lưu trên máy và vẫn xem offline. Ảnh local đang bị thiếu.',
      ),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('downloads missing cloud media only after the user taps',
      (tester) async {
    final cloudBytes = Uint8List.fromList([1, 2, 3, 4]);
    final snapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cloud image',
      syncStatus: SyncStatus.synced,
      detectionCount: 1,
      remoteDisplayPath: '$_userId/media/display.jpg',
      mediaBytes: cloudBytes,
    );
    final remote = _FakeCloudMediaSource(bytes: cloudBytes);
    final writer = _FakeLocalMediaWriter();
    final restoreService = LibraryCloudMediaRestoreService(
      remote: remote,
      local: writer,
    );

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [snapshot.photoNote],
        snapshots: {snapshot.photoNote.id: snapshot},
      ),
      loader: _FakeMediaLoader(fail: true),
      screen: LibraryPhotoNoteDetailScreen(photoNoteId: snapshot.photoNote.id),
      location: '/storage/${snapshot.photoNote.id}',
      cloudMediaRestoreService: restoreService,
    );

    expect(find.text('Tải ảnh từ cloud'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('library-photo-note-detail')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Từ vựng đã lưu trên máy. Ảnh vẫn ở Cloud Backup và chỉ tải khi bạn chọn.',
      ),
      findsOneWidget,
    );
    expect(remote.downloadCount, 0);
    expect(writer.writes, isEmpty);

    await tester.drag(
      find.byKey(const Key('library-photo-note-detail')),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải ảnh từ cloud'));
    await tester.pumpAndSettle();

    expect(remote.downloadCount, 1);
    expect(writer.writes[snapshot.mediaAsset.displayRelativePath], cloudBytes);
    expect(find.text('Đã tải ảnh về thiết bị.'), findsOneWidget);
  });

  testWidgets('confirms quarantine, restore and permanent local delete',
      (tester) async {
    final recoveryStore = _FakeRecoveryStore(
      managed: {'capy_scans/orphan.jpg'},
      quarantined: {
        'capy_quarantine/recover.jpg': DateTime.utc(2026, 9, 1),
      },
    );
    final recoveryService = LibraryMediaRecoveryService(
      loadReferencedPaths: () async => {'capy_scans/missing.jpg'},
      store: recoveryStore,
    );

    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(notes: const [], snapshots: const {}),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
      recoveryService: recoveryService,
      recoverySnapshot: await recoveryService.inspect(),
    );

    expect(find.byKey(const Key('library-media-recovery-banner')), findsOne);
    await tester.tap(find.byKey(const Key('library-media-recovery-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-media-recovery-sheet')), findsOne);
    expect(find.byKey(const Key('library-media-missing-info')), findsOne);

    await tester.tap(
      find.byKey(const Key('library-quarantine-capy_scans/orphan.jpg')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cách ly ảnh này?'), findsOne);
    await tester.tap(
      find.byKey(const Key('library-recovery-confirm-action')),
    );
    await tester.pumpAndSettle();
    expect(recoveryStore.managed, isNot(contains('capy_scans/orphan.jpg')));
    expect(
      recoveryStore.quarantined,
      contains('capy_quarantine/orphan.jpg'),
    );

    await tester.scrollUntilVisible(
      find.byKey(
        const Key('library-restore-capy_quarantine/recover.jpg'),
      ),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('library-media-recovery-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(
      find.byKey(
        const Key('library-restore-capy_quarantine/recover.jpg'),
      ),
    );
    await tester.pumpAndSettle();
    expect(recoveryStore.managed, contains('capy_scans/recover.jpg'));

    if (find
        .byKey(const Key('library-media-recovery-sheet'))
        .evaluate()
        .isEmpty) {
      await tester.tap(find.byKey(const Key('library-media-recovery-banner')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('library-delete-capy_quarantine/orphan.jpg')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('library-media-recovery-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.byKey(const Key('library-media-recovery-sheet')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('library-delete-capy_quarantine/orphan.jpg')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xóa ảnh vĩnh viễn?'), findsOne);
    await tester.tap(
      find.byKey(const Key('library-recovery-confirm-action')),
    );
    await tester.pumpAndSettle();
    expect(
      recoveryStore.quarantined,
      isNot(contains('capy_quarantine/orphan.jpg')),
    );
  });

  testWidgets('builds Library photo cards lazily while scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snapshots = List.generate(
      40,
      (index) => _snapshot(
        noteId: '40000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        suffix: '${index + 10}',
        title: 'Photo $index',
        syncStatus: SyncStatus.localOnly,
        detectionCount: 1,
      ),
    );
    final lastId = snapshots.last.photoNote.id;
    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: snapshots.map((snapshot) => snapshot.photoNote).toList(),
        snapshots: {
          for (final snapshot in snapshots) snapshot.photoNote.id: snapshot,
        },
      ),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    expect(find.byKey(Key('library-photo-note-$lastId')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(Key('library-photo-note-$lastId')),
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('library-page-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(Key('library-photo-note-$lastId')), findsOneWidget);
  });

  testWidgets('meets Android tap-target guidance across Library tabs',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final active = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
    );
    final deleted = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Window',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      deletedAt: _createdAt,
    );
    try {
      await _pumpLibrary(
        tester,
        repository: _FakeLibraryRepository(
          notes: [active.photoNote, deleted.photoNote],
          snapshots: {
            active.photoNote.id: active,
            deleted.photoNote.id: deleted,
          },
        ),
        albumRepository: _FakeAlbumRepository(
          albums: [_album(name: 'Travel', icon: '✈️')],
        ),
        loader: _FakeMediaLoader(),
        screen: const StorageAlbumScreen(),
      );

      expect(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(const Key('library-albums-tab')));
      await tester.pumpAndSettle();
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.byKey(const Key('library-trash-tab')));
      await tester.pumpAndSettle();
      expect(tester, meetsGuideline(androidTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps the Library usable on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    final activeSnapshot = _snapshot(
      noteId: _firstNoteId,
      suffix: '1',
      title: 'Cup, table',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 2,
    );
    final trashSnapshot = _snapshot(
      noteId: _secondNoteId,
      suffix: '2',
      title: 'Window',
      syncStatus: SyncStatus.localOnly,
      detectionCount: 1,
      deletedAt: _createdAt,
    );
    await _pumpLibrary(
      tester,
      repository: _FakeLibraryRepository(
        notes: [activeSnapshot.photoNote, trashSnapshot.photoNote],
        snapshots: {
          activeSnapshot.photoNote.id: activeSnapshot,
          trashSnapshot.photoNote.id: trashSnapshot,
        },
      ),
      albumRepository: _FakeAlbumRepository(
        albums: [_album(name: 'Travel', icon: '✈️')],
      ),
      loader: _FakeMediaLoader(),
      screen: const StorageAlbumScreen(),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('library-albums-tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('library-trash-tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required LibraryRepository repository,
  AlbumRepository? albumRepository,
  required LibraryMediaLoader loader,
  required Widget screen,
  String location = '/storage',
  LibraryMediaRecoveryService? recoveryService,
  LibraryMediaRecoverySnapshot? recoverySnapshot,
  LibraryCloudMediaRestoreService? cloudMediaRestoreService,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/storage',
        builder: (context, state) => screen,
      ),
      GoRoute(
        path: '/storage/vocabulary',
        builder: (context, state) {
          final notes = state.extra;
          return notes is List<PhotoNote>
              ? SelectedPhotoVocabularyScreen(notes: notes)
              : screen;
        },
      ),
      GoRoute(
        path: '/storage/:photoNoteId',
        builder: (context, state) => screen,
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const Scaffold(body: Text('Scan')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentLibraryUserIdProvider.overrideWithValue(_userId),
        libraryRepositoryProvider.overrideWith((ref) async => repository),
        if (albumRepository != null)
          albumRepositoryProvider.overrideWith((ref) async => albumRepository),
        libraryMediaLoaderProvider.overrideWithValue(loader),
        libraryMediaRecoveryServiceProvider
            .overrideWith((ref) async => recoveryService),
        libraryPhotoNoteDeletionServiceProvider
            .overrideWith((ref) async => null),
        libraryMediaRecoverySnapshotProvider.overrideWith(
          (ref) async {
            if (recoveryService == null) return recoverySnapshot;
            return recoveryService.inspect();
          },
        ),
        libraryCloudMediaRestoreServiceProvider.overrideWithValue(
          cloudMediaRestoreService,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeRecoveryStore implements LibraryMediaRecoveryStore {
  _FakeRecoveryStore({
    required Set<String> managed,
    required Map<String, DateTime> quarantined,
  })  : managed = Set.of(managed),
        quarantined = Map.of(quarantined);

  final Set<String> managed;
  final Map<String, DateTime> quarantined;

  @override
  Future<void> deleteQuarantined(String quarantinedRelativePath) async {
    quarantined.remove(quarantinedRelativePath);
  }

  @override
  Future<bool> exists(String relativePath) async =>
      managed.contains(relativePath);

  @override
  Future<Set<String>> listManagedRelativePaths() async => Set.of(managed);

  @override
  Future<List<QuarantinedLibraryMedia>> listQuarantined() async =>
      quarantined.entries
          .map((entry) => QuarantinedLibraryMedia(
                relativePath: entry.key,
                quarantinedAt: entry.value,
              ))
          .toList(growable: false);

  @override
  Future<int> purgeExpired({
    required DateTime now,
    required Duration retention,
  }) async {
    final expired = quarantined.entries
        .where((entry) => !entry.value.isAfter(now.subtract(retention)))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final path in expired) {
      quarantined.remove(path);
    }
    return expired.length;
  }

  @override
  Future<void> quarantine({
    required String managedRelativePath,
    required DateTime quarantinedAt,
  }) async {
    managed.remove(managedRelativePath);
    quarantined[managedRelativePath.replaceFirst(
        'capy_scans/', 'capy_quarantine/')] = quarantinedAt;
  }

  @override
  Future<void> restore(String quarantinedRelativePath) async {
    final removed = quarantined.remove(quarantinedRelativePath);
    if (removed == null) throw StateError('missing');
    managed.add(
      quarantinedRelativePath.replaceFirst('capy_quarantine/', 'capy_scans/'),
    );
  }
}

PhotoNoteSnapshot _snapshot({
  required String noteId,
  required String suffix,
  required String title,
  required SyncStatus syncStatus,
  required int detectionCount,
  DateTime? createdAt,
  DateTime? deletedAt,
  String? remoteDisplayPath,
  Uint8List? mediaBytes,
}) {
  final suffixValue = int.tryParse(suffix) ?? suffix.hashCode.abs();
  final entityTail = suffixValue.toRadixString(16).padLeft(12, '0');
  final mediaId = '20000000-0000-4000-8000-$entityTail';
  final scanId = '30000000-0000-4000-8000-$entityTail';
  final detections = List.generate(
    detectionCount,
    (index) => VocabDetection(
      id: '50000000-0000-4000-8000-${(suffixValue * 100 + index + 1).toRadixString(16).padLeft(12, '0')}',
      scanRunId: scanId,
      wordRaw: 'word ${index + 1}',
      wordNormalized: 'word ${index + 1}',
      phonetic: '/wɜːd/',
      meaningVi: 'nghĩa ${index + 1}',
      partOfSpeech: 'noun',
      exampleEn: 'Example ${index + 1}',
      exampleVi: 'Ví dụ ${index + 1}',
      boundingBox: NormalizedBoundingBox(
        x: 0.2,
        y: 0.2,
        width: 0.2,
        height: 0.2,
      ),
      displayOrder: index,
      createdAt: _createdAt,
    ),
  );
  return PhotoNoteSnapshot(
    photoNote: PhotoNote(
      id: noteId,
      userId: _userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: title,
      templateId: 'standard',
      createdAt: createdAt ?? _createdAt,
      updatedAt: createdAt ?? _createdAt,
      deletedAt: deletedAt,
      syncStatus: syncStatus,
    ),
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: _userId,
      contentHashSha256: mediaBytes == null
          ? 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          : sha256.convert(mediaBytes).toString(),
      displayRelativePath: 'capy_scans/scan_$suffix.jpg',
      remoteDisplayPath: remoteDisplayPath,
      mimeType: 'image/jpeg',
      width: 640,
      height: 480,
      orientation: 0,
      byteSizeDisplay: mediaBytes?.length ?? 68,
      preprocessingVersion: 'scan-jpeg-v1',
      captureSource: CaptureSource.camera,
      capturedAt: _createdAt,
      createdAt: _createdAt,
      syncStatus: syncStatus,
    ),
    primaryScanRun: ScanRun(
      id: scanId,
      userId: _userId,
      mediaAssetId: mediaId,
      requestId: 'request-$suffix',
      provider: 'google_gemini',
      modelName: 'gemini-test',
      promptVersion: 'prompt-v1',
      responseSchemaVersion: 'schema-v1',
      preprocessingVersion: 'scan-jpeg-v1',
      rawResponseJson: const {'words': []},
      responseHashSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      status: ScanRunStatus.succeeded,
      startedAt: _createdAt.subtract(const Duration(seconds: 1)),
      completedAt: _createdAt,
    ),
    detections: detections,
    annotations: const [],
  );
}

final class _FakeMediaLoader implements LibraryMediaLoader {
  _FakeMediaLoader({this.fail = false, this.missingPaths = const {}});

  final bool fail;
  final Set<String> missingPaths;

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    if (fail || missingPaths.contains(relativePath)) {
      throw const LibraryMediaLoadException('missing');
    }
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<int> sizeBytes(String relativePath) async {
    return (await readBytes(relativePath)).length;
  }
}

final class _FakeCloudMediaSource implements LibraryCloudMediaSource {
  _FakeCloudMediaSource({required this.bytes});

  final Uint8List bytes;
  int downloadCount = 0;

  @override
  String? get authenticatedUserId => _userId;

  @override
  Future<Uint8List> downloadPrivateMedia(String objectPath) async {
    downloadCount++;
    return bytes;
  }
}

final class _FakeLocalMediaWriter implements LibraryLocalMediaWriter {
  final Map<String, Uint8List> writes = {};

  @override
  Future<void> writeAtomically({
    required String relativePath,
    required Uint8List bytes,
  }) async {
    writes[relativePath] = bytes;
  }
}

Album _album({
  String id = _firstAlbumId,
  required String name,
  required String icon,
  bool isFavorite = false,
}) {
  return Album(
    id: id,
    userId: _userId,
    name: name,
    icon: icon,
    isFavorite: isFavorite,
    createdAt: _createdAt,
    updatedAt: _createdAt,
    syncStatus: SyncStatus.localOnly,
  );
}

final class _FakeAlbumRepository implements AlbumRepository {
  _FakeAlbumRepository({
    required List<Album> albums,
    this.failCreateAlbumWithPhotoNotes = false,
  }) : albums = List.of(albums);

  final List<Album> albums;
  final bool failCreateAlbumWithPhotoNotes;
  final Map<String, List<AlbumPhotoNote>> memberships = {};
  final List<String> addedPhotoNoteIds = [];
  final StreamController<void> _albumChanges =
      StreamController<void>.broadcast(sync: true);
  final StreamController<void> _membershipChanges =
      StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<Album>> watchAlbums({
    required String userId,
    bool includeDeleted = false,
  }) async* {
    yield _sortedAlbums();
    yield* _albumChanges.stream.map((_) => _sortedAlbums());
  }

  @override
  Stream<List<AlbumPhotoNote>> watchMemberships({
    required String userId,
    required String albumId,
  }) async* {
    List<AlbumPhotoNote> current() =>
        List.unmodifiable(memberships[albumId] ?? const []);
    yield current();
    yield* _membershipChanges.stream.map((_) => current());
  }

  @override
  Future<void> saveAlbum(Album album) async {
    albums.add(album);
    _albumChanges.add(null);
  }

  @override
  Future<void> createAlbumWithPhotoNotes({
    required Album album,
    required Iterable<String> photoNoteIds,
    required DateTime addedAt,
    required String operationId,
  }) async {
    if (failCreateAlbumWithPhotoNotes) {
      throw StateError('Initial Photo Note assignment failed');
    }
    await saveAlbum(album);
    await addPhotoNotes(
      userId: album.userId,
      albumId: album.id,
      photoNoteIds: photoNoteIds,
      addedAt: addedAt,
      operationId: operationId,
    );
  }

  @override
  Future<void> setFavorite({
    required String userId,
    required String albumId,
    required bool isFavorite,
    required DateTime updatedAt,
  }) async {
    final index = albums.indexWhere((album) => album.id == albumId);
    final current = albums[index];
    albums[index] = Album(
      id: current.id,
      userId: current.userId,
      name: current.name,
      icon: current.icon,
      isFavorite: isFavorite,
      createdAt: current.createdAt,
      updatedAt: updatedAt,
      syncStatus: current.syncStatus,
    );
    _albumChanges.add(null);
  }

  @override
  Future<void> addPhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime addedAt,
    required String operationId,
  }) async {
    final ids = photoNoteIds.toList(growable: false);
    addedPhotoNoteIds.addAll(ids);
    final items = memberships.putIfAbsent(albumId, () => []);
    for (final photoNoteId in ids) {
      items.add(AlbumPhotoNote(
        albumId: albumId,
        photoNoteId: photoNoteId,
        addedAt: addedAt,
        operationId: operationId,
      ));
    }
    _membershipChanges.add(null);
  }

  @override
  Future<void> removePhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime removedAt,
    required String operationId,
  }) async {
    final ids = photoNoteIds.toSet();
    memberships[albumId]?.removeWhere(
      (membership) => ids.contains(membership.photoNoteId),
    );
    _membershipChanges.add(null);
  }

  @override
  Future<void> deleteAlbums({
    required String userId,
    required Iterable<String> albumIds,
    required DateTime deletedAt,
  }) async {
    final ids = albumIds.toSet();
    albums.removeWhere((album) => ids.contains(album.id));
    for (final id in ids) {
      memberships.remove(id);
    }
    _albumChanges.add(null);
    _membershipChanges.add(null);
  }

  List<Album> _sortedAlbums() {
    final result = List<Album>.of(albums);
    result.sort((left, right) {
      final favorite = right.isFavorite.toString().compareTo(
            left.isFavorite.toString(),
          );
      if (favorite != 0) return favorite;
      return right.createdAt.compareTo(left.createdAt);
    });
    return result;
  }

  Future<void> dispose() async {
    await _albumChanges.close();
    await _membershipChanges.close();
  }
}

final class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository({
    required this.notes,
    required this.snapshots,
    this.albumPhotoNoteIds = const {},
    this.failAlbumPhotoNoteQuery = false,
  });

  final List<PhotoNote> notes;
  final Map<String, PhotoNoteSnapshot> snapshots;
  final Map<String, List<String>> albumPhotoNoteIds;
  final bool failAlbumPhotoNoteQuery;
  final Set<String> permanentDeletionIds = {};
  int snapshotReadCount = 0;

  @override
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query) {
    if (query.albumId != null && failAlbumPhotoNoteQuery) {
      return Stream.error(StateError('Album Photo Note query failed'));
    }
    return Stream.value(
      notes.where((note) {
        if (permanentDeletionIds.contains(note.id)) return false;
        final albumIds =
            query.albumId == null ? null : albumPhotoNoteIds[query.albumId];
        if (albumIds != null && !albumIds.contains(note.id)) return false;
        return switch (query.visibility) {
          PhotoNoteVisibility.active => !note.isDeleted,
          PhotoNoteVisibility.trash => note.isDeleted,
          PhotoNoteVisibility.all => true,
        };
      }).toList(growable: false),
    );
  }

  @override
  Stream<LibraryStorageSummary> watchStorageSummary({required String userId}) {
    final visible = notes
        .where((note) =>
            note.userId == userId && !permanentDeletionIds.contains(note.id))
        .toList(growable: false);
    final mediaIds = <String>{};
    var bytes = 0;
    for (final note in visible) {
      final media = snapshots[note.id]?.mediaAsset;
      if (media != null && mediaIds.add(media.id)) {
        bytes += media.byteSizeDisplay;
      }
    }
    return Stream.value(LibraryStorageSummary(
      activeCount: visible.where((note) => !note.isDeleted).length,
      trashCount: visible.where((note) => note.isDeleted).length,
      localMediaBytes: bytes,
      localMediaCount: 0,
      cloudOnlyMediaCount: 0,
      missingMediaCount: 0,
    ));
  }

  @override
  Future<List<MediaAsset>> getStorageMediaAssets(
      {required String userId}) async {
    final mediaIds = <String>{};
    final assets = <MediaAsset>[];
    for (final note in notes) {
      if (note.userId != userId || permanentDeletionIds.contains(note.id)) {
        continue;
      }
      final media = snapshots[note.id]?.mediaAsset;
      if (media != null && mediaIds.add(media.id)) assets.add(media);
    }
    return assets;
  }

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async {
    snapshotReadCount++;
    return snapshots[photoNoteId];
  }

  @override
  Future<void> movePhotoNotesToTrash({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime deletedAt,
  }) async {
    for (final id in photoNoteIds) {
      _replaceNote(id, deletedAt: deletedAt);
    }
  }

  @override
  Future<void> requestPermanentDeletion({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime requestedAt,
  }) async {
    permanentDeletionIds.addAll(photoNoteIds);
  }

  @override
  Future<void> restorePhotoNotes({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime restoredAt,
  }) async {
    for (final id in photoNoteIds) {
      _replaceNote(id, deletedAt: null, clearDeletedAt: true);
    }
  }

  @override
  Future<void> saveCapturedPhotoNote(PhotoNoteSnapshot snapshot) async {}

  void _replaceNote(
    String id, {
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    final index = notes.indexWhere((note) => note.id == id);
    final current = notes[index];
    notes[index] = PhotoNote(
      id: current.id,
      userId: current.userId,
      mediaAssetId: current.mediaAssetId,
      primaryScanRunId: current.primaryScanRunId,
      title: current.title,
      emoji: current.emoji,
      templateId: current.templateId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: clearDeletedAt ? null : deletedAt ?? current.deletedAt,
      syncStatus: current.syncStatus,
    );
  }
}
