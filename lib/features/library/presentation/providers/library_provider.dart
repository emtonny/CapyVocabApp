import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_scan/presentation/providers/scan_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../application/library_media_loader.dart';
import '../../data/local/library_media_loader_factory.dart';
import '../../domain/entities/library_enums.dart';
import '../../domain/entities/photo_note.dart';
import '../../domain/entities/photo_note_snapshot.dart';
import '../../domain/repositories/library_repository.dart';

final currentLibraryUserIdProvider = Provider<String?>((ref) {
  ref.watch(authProvider);
  return ref.watch(authRepositoryProvider).currentUser?.id;
});

final libraryRepositoryProvider =
    FutureProvider<LibraryRepository>((ref) async {
  return ref.watch(libraryStoreProvider.future);
});

final libraryMediaLoaderProvider = Provider<LibraryMediaLoader>((ref) {
  return createLibraryMediaLoader();
});

final libraryPhotoNotesProvider =
    StreamProvider.autoDispose<List<PhotoNote>>((ref) async* {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) {
    yield const <PhotoNote>[];
    return;
  }

  final repository = await ref.watch(libraryRepositoryProvider.future);
  yield* repository.watchPhotoNotes(PhotoNoteQuery(userId: userId));
});

final libraryTrashPhotoNotesProvider =
    StreamProvider.autoDispose<List<PhotoNote>>((ref) async* {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) {
    yield const <PhotoNote>[];
    return;
  }

  final repository = await ref.watch(libraryRepositoryProvider.future);
  yield* repository.watchPhotoNotes(
    PhotoNoteQuery(
      userId: userId,
      visibility: PhotoNoteVisibility.trash,
    ),
  );
});

final libraryStorageSummaryProvider =
    StreamProvider.autoDispose<LibraryStorageSummary>((ref) async* {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) {
    yield const LibraryStorageSummary(
      activeCount: 0,
      trashCount: 0,
      localMediaBytes: 0,
      localMediaCount: 0,
      cloudOnlyMediaCount: 0,
      missingMediaCount: 0,
    );
    return;
  }

  final repository = await ref.watch(libraryRepositoryProvider.future);
  final mediaLoader = ref.watch(libraryMediaLoaderProvider);
  await for (final databaseSummary
      in repository.watchStorageSummary(userId: userId)) {
    final assets = await repository.getStorageMediaAssets(userId: userId);
    var localMediaBytes = 0;
    var localMediaCount = 0;
    var cloudOnlyMediaCount = 0;
    var missingMediaCount = 0;

    for (final asset in assets) {
      try {
        localMediaBytes +=
            await mediaLoader.sizeBytes(asset.displayRelativePath);
        localMediaCount++;
      } on LibraryMediaLoadException {
        if (asset.remoteDisplayPath == null) {
          missingMediaCount++;
        } else {
          cloudOnlyMediaCount++;
        }
      }

      final originalPath = asset.originalRelativePath;
      if (originalPath != null && originalPath != asset.displayRelativePath) {
        try {
          localMediaBytes += await mediaLoader.sizeBytes(originalPath);
        } on LibraryMediaLoadException {
          // A missing optional original must not hide the available display
          // rendition or turn cloud metadata into local bytes.
        }
      }
    }

    yield LibraryStorageSummary(
      activeCount: databaseSummary.activeCount,
      trashCount: databaseSummary.trashCount,
      localMediaBytes: localMediaBytes,
      localMediaCount: localMediaCount,
      cloudOnlyMediaCount: cloudOnlyMediaCount,
      missingMediaCount: missingMediaCount,
    );
  }
});

final libraryPhotoNoteSnapshotProvider = FutureProvider.autoDispose
    .family<PhotoNoteSnapshot?, String>((ref, photoNoteId) async {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) return null;

  final repository = await ref.watch(libraryRepositoryProvider.future);
  return repository.getPhotoNoteSnapshot(
    userId: userId,
    photoNoteId: photoNoteId,
  );
});

final libraryMediaBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, relativePath) async {
  return ref.watch(libraryMediaLoaderProvider).readBytes(relativePath);
});
