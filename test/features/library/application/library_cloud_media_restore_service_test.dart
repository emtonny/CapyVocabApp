import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_cloud_media_restore_service.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/media_asset.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '10000000-0000-4000-8000-000000000001';
final _createdAt = DateTime.utc(2026, 9, 9);

void main() {
  test('downloads and atomically writes only after explicit restore call',
      () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final remote = _FakeCloudMediaSource(userId: _userId, bytes: bytes);
    final local = _FakeLocalMediaWriter();
    final service = LibraryCloudMediaRestoreService(
      remote: remote,
      local: local,
    );
    final asset = _asset(bytes);

    expect(remote.downloadCount, 0,
        reason: 'constructing the service must not start a download');
    expect(local.writes, isEmpty);

    await service.restoreDisplay(asset);

    expect(remote.downloadCount, 1);
    expect(remote.lastObjectPath, '$_userId/media/display.jpg');
    expect(local.writes[asset.displayRelativePath], bytes);
  });

  test('fails closed before download when auth owner does not match', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final remote = _FakeCloudMediaSource(
      userId: '10000000-0000-4000-8000-000000000002',
      bytes: bytes,
    );
    final local = _FakeLocalMediaWriter();
    final service = LibraryCloudMediaRestoreService(
      remote: remote,
      local: local,
    );

    await expectLater(
      service.restoreDisplay(_asset(bytes)),
      throwsA(
        isA<LibraryCloudMediaRestoreException>().having(
          (error) => error.code,
          'code',
          'auth_owner_mismatch',
        ),
      ),
    );
    expect(remote.downloadCount, 0);
    expect(local.writes, isEmpty);
  });

  test('rejects corrupt cloud bytes without writing local media', () async {
    final expected = Uint8List.fromList([1, 2, 3, 4]);
    final remote = _FakeCloudMediaSource(
      userId: _userId,
      bytes: Uint8List.fromList([4, 3, 2, 1]),
    );
    final local = _FakeLocalMediaWriter();
    final service = LibraryCloudMediaRestoreService(
      remote: remote,
      local: local,
    );

    await expectLater(
      service.restoreDisplay(_asset(expected)),
      throwsA(
        isA<LibraryCloudMediaRestoreException>().having(
          (error) => error.code,
          'code',
          'cloud_media_hash_mismatch',
        ),
      ),
    );
    expect(local.writes, isEmpty);
  });
}

MediaAsset _asset(Uint8List expectedBytes) => MediaAsset(
      id: '20000000-0000-4000-8000-000000000001',
      userId: _userId,
      contentHashSha256: sha256.convert(expectedBytes).toString(),
      displayRelativePath: 'capy_scans/display.jpg',
      remoteDisplayPath: '$_userId/media/display.jpg',
      mimeType: 'image/jpeg',
      width: 10,
      height: 10,
      orientation: 0,
      byteSizeDisplay: expectedBytes.length,
      preprocessingVersion: 'test-v1',
      captureSource: CaptureSource.camera,
      createdAt: _createdAt,
      syncStatus: SyncStatus.synced,
    );

final class _FakeCloudMediaSource implements LibraryCloudMediaSource {
  _FakeCloudMediaSource({required String? userId, required this.bytes})
      : _userId = userId;

  final String? _userId;
  final Uint8List bytes;
  int downloadCount = 0;
  String? lastObjectPath;

  @override
  String? get authenticatedUserId => _userId;

  @override
  Future<Uint8List> downloadPrivateMedia(String objectPath) async {
    downloadCount++;
    lastObjectPath = objectPath;
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
