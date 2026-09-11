import 'dart:convert';
import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/library_media_loader_factory_io.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/local_account.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note.dart';
import 'package:capy_vocab/features/library/domain/entities/photo_note_snapshot.dart';
import 'package:capy_vocab/features/library/domain/entities/scan_models.dart';
import 'package:capy_vocab/features/library/domain/repositories/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '61000000-0000-4000-8000-000000000001';
const _mediaId = '62000000-0000-4000-8000-000000000001';
const _scanId = '63000000-0000-4000-8000-000000000001';
const _noteId = '64000000-0000-4000-8000-000000000001';
const _detectionId = '65000000-0000-4000-8000-000000000001';
final _time = DateTime.utc(2026, 9, 6, 2);

void main() {
  setUpAll(sqfliteFfiInit);

  test('reopens SQLite and app-private media without network', () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('library_offline_ui_');
    final databasePath =
        '${temporaryDirectory.path}${Platform.pathSeparator}library.db';
    final firstDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    LibraryDatabase? reopenedDatabase;
    SqliteLibraryStore? reopenedStore;

    try {
      final firstStore = SqliteLibraryStore(
        database: await firstDatabase.open(),
        idGenerator: () => '66000000-0000-4000-8000-000000000001',
        clock: () => _time,
      );
      await firstStore.saveLocalAccount(_account());
      await firstStore.saveCapturedPhotoNote(_snapshot());
      await firstStore.dispose();
      await firstDatabase.close();

      final imageDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans',
      );
      await imageDirectory.create();
      await File(
        '${imageDirectory.path}${Platform.pathSeparator}reopened.jpg',
      ).writeAsBytes(_imageBytes());

      reopenedDatabase = LibraryDatabase(
        factory: databaseFactoryFfi,
        path: databasePath,
      );
      reopenedStore = SqliteLibraryStore(
        database: await reopenedDatabase.open(),
        idGenerator: () => '66000000-0000-4000-8000-000000000002',
        clock: () => _time,
      );

      final restored = await reopenedStore.getPhotoNoteSnapshot(
        userId: _userId,
        photoNoteId: _noteId,
      );
      final listed = await reopenedStore
          .watchPhotoNotes(PhotoNoteQuery(userId: _userId))
          .first;
      final bytes = await IoLibraryMediaLoader(
        documentsDirectory: () async => temporaryDirectory,
      ).readBytes(restored!.mediaAsset.displayRelativePath);

      expect(listed.single.title, 'Offline restart');
      expect(restored.detections.single.wordNormalized, 'reopen');
      expect(restored.detections.single.meaningVi, 'mở lại');
      expect(bytes, _imageBytes());
    } finally {
      await reopenedStore?.dispose();
      await reopenedDatabase?.close();
      await firstDatabase.close();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });
}

LocalAccount _account() => LocalAccount(
      userId: _userId,
      accountState: AccountState.active,
      cloudBackupEnabled: false,
      localPersonalizationEnabled: false,
      federatedContributionEnabled: false,
      lastAuthenticatedAt: _time,
      createdAt: _time,
      updatedAt: _time,
    );

PhotoNoteSnapshot _snapshot() => PhotoNoteSnapshot(
      photoNote: PhotoNote(
        id: _noteId,
        userId: _userId,
        mediaAssetId: _mediaId,
        primaryScanRunId: _scanId,
        title: 'Offline restart',
        templateId: 'standard',
        createdAt: _time,
        updatedAt: _time,
        syncStatus: SyncStatus.localOnly,
      ),
      mediaAsset: MediaAsset(
        id: _mediaId,
        userId: _userId,
        contentHashSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        displayRelativePath: 'capy_scans/reopened.jpg',
        mimeType: 'image/jpeg',
        width: 1,
        height: 1,
        orientation: 0,
        byteSizeDisplay: _imageBytes().length,
        preprocessingVersion: 'scan-jpeg-v1',
        captureSource: CaptureSource.camera,
        capturedAt: _time,
        createdAt: _time,
        syncStatus: SyncStatus.localOnly,
      ),
      primaryScanRun: ScanRun(
        id: _scanId,
        userId: _userId,
        mediaAssetId: _mediaId,
        requestId: 'offline-restart-request',
        provider: 'google_gemini',
        modelName: 'gemini-test',
        promptVersion: 'prompt-v1',
        responseSchemaVersion: 'schema-v1',
        preprocessingVersion: 'scan-jpeg-v1',
        rawResponseJson: const {'words': []},
        responseHashSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        status: ScanRunStatus.succeeded,
        startedAt: _time.subtract(const Duration(seconds: 1)),
        completedAt: _time,
      ),
      detections: [
        VocabDetection(
          id: _detectionId,
          scanRunId: _scanId,
          wordRaw: 'reopen',
          wordNormalized: 'reopen',
          meaningVi: 'mở lại',
          displayOrder: 0,
          createdAt: _time,
        ),
      ],
      annotations: const [],
    );

List<int> _imageBytes() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
