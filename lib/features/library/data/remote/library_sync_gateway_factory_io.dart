import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/library_cloud_media_restore_service.dart';
import '../../application/library_sync_gateway.dart';
import '../local/library_media_writer_factory.dart';
import 'supabase_library_sync_gateway.dart';

LibraryRuntimeGateway createLibrarySyncGateway(SupabaseClient client) {
  return SupabaseLibrarySyncGateway(
    client: client,
    resolveLocalMedia: (relativePath) async {
      final documents = await getApplicationDocumentsDirectory();
      final platformPath = relativePath.replaceAll('/', Platform.pathSeparator);
      return File(
        '${documents.path}${Platform.pathSeparator}$platformPath',
      );
    },
  );
}

LibraryCloudMediaRestoreService createLibraryCloudMediaRestoreService(
  SupabaseClient client,
) {
  return LibraryCloudMediaRestoreService(
    remote: _SupabaseLibraryCloudMediaSource(client),
    local: createLibraryLocalMediaWriter()!,
  );
}

final class _SupabaseLibraryCloudMediaSource
    implements LibraryCloudMediaSource {
  const _SupabaseLibraryCloudMediaSource(this._client);

  final SupabaseClient _client;

  @override
  String? get authenticatedUserId => _client.auth.currentUser?.id;

  @override
  Future<Uint8List> downloadPrivateMedia(String objectPath) {
    return _client.storage.from('photo_notes').download(objectPath);
  }
}
