import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/application/library_media_recovery_service.dart';
import 'package:capy_vocab/features/library/application/library_cloud_media_restore_service.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_cloud_media_restore_provider.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_media_integrity_provider.dart';
import 'package:capy_vocab/features/library/presentation/screens/storage_album_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
const _firstNoteId = '40000000-0000-4000-8000-000000000001';
const _secondNoteId = '40000000-0000-4000-8000-000000000002';
const _thirdNoteId = '40000000-0000-4000-8000-000000000003';
final _createdAt = DateTime.utc(2026, 9, 6, 1, 7);

void main() {
  testWidgets('lists saved notes from the offline repository and opens one',
      (tester) async {
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
    String? openedId;

    await _pumpLibrary(
      tester,
      repository: repository,
      loader: _FakeMediaLoader(),
      screen: StorageAlbumScreen(
        onOpenPhotoNote: (value) => openedId = value,
      ),
    );

    expect(find.byKey(const Key('library-photo-note-list')), findsOneWidget);
    expect(find.text('2 bài trong thư viện'), findsOneWidget);
    expect(find.textContaining('Cup, table'), findsOneWidget);
    expect(find.textContaining('Window'), findsOneWidget);
    expect(find.textContaining('2 từ vựng'), findsOneWidget);
    expect(find.text('Đã sao lưu'), findsOneWidget);
    expect(find.text('Chỉ trên máy'), findsOneWidget);
    expect(find.byKey(const Key('library-storage-summary')), findsOneWidget);
    expect(find.textContaining('2/2 ảnh trên máy • 136 B'), findsOneWidget);
    expect(find.text('Ảnh trên máy'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const Key('library-photo-note-$_firstNoteId')),
    );
    await tester.pump();

    expect(openedId, _firstNoteId);
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

    expect(find.text('3 bài trong thư viện'), findsOneWidget);
    expect(find.textContaining('1/3 ảnh trên máy • 68 B'), findsOneWidget);
    expect(find.textContaining('1 trên cloud\n1 bị thiếu'), findsOneWidget);
    expect(find.text('Ảnh trên máy'), findsOneWidget);
    expect(find.text('Ảnh trên cloud'), findsOneWidget);
    expect(find.text('Thiếu ảnh'), findsOneWidget);
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
    await tester.tap(find.text('Đưa vào thùng rác'));
    await tester.pumpAndSettle();
    expect(find.text('Chuyển bài vào thùng rác?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('library-trash-confirm-action')),
    );
    await tester.pumpAndSettle();

    expect(repository.notes.single.deletedAt, isNotNull);
    expect(find.byKey(Key('library-photo-note-${snapshot.photoNote.id}')),
        findsNothing);
  });

  testWidgets('Trash restores a note and queues explicit permanent deletion',
      (tester) async {
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
    await tester.tap(
      find.byKey(Key('library-trash-restore-${restoreSnapshot.photoNote.id}')),
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
    expect(find.text('Offline'), findsOneWidget);
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
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required LibraryRepository repository,
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
  DateTime? deletedAt,
  String? remoteDisplayPath,
  Uint8List? mediaBytes,
}) {
  final mediaId = '20000000-0000-4000-8000-00000000000$suffix';
  final scanId = '30000000-0000-4000-8000-00000000000$suffix';
  final detections = List.generate(
    detectionCount,
    (index) => VocabDetection(
      id: '50000000-0000-4000-8000-0000000000$suffix${index + 1}',
      scanRunId: scanId,
      wordRaw: 'word ${index + 1}',
      wordNormalized: 'word ${index + 1}',
      phonetic: '/wɜːd/',
      meaningVi: 'nghĩa ${index + 1}',
      partOfSpeech: 'noun',
      exampleEn: 'Example ${index + 1}',
      exampleVi: 'Ví dụ ${index + 1}',
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
      createdAt: _createdAt,
      updatedAt: _createdAt,
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

final class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository({required this.notes, required this.snapshots});

  final List<PhotoNote> notes;
  final Map<String, PhotoNoteSnapshot> snapshots;
  final Set<String> permanentDeletionIds = {};
  int snapshotReadCount = 0;

  @override
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query) {
    return Stream.value(
      notes.where((note) {
        if (permanentDeletionIds.contains(note.id)) return false;
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
