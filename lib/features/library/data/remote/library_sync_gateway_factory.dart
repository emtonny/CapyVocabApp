import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/library_cloud_media_restore_service.dart';
import '../../application/library_sync_gateway.dart';
import 'library_sync_gateway_factory_stub.dart'
    if (dart.library.io) 'library_sync_gateway_factory_io.dart' as platform;

LibraryRuntimeGateway? createLibrarySyncGateway(SupabaseClient client) {
  return platform.createLibrarySyncGateway(client);
}

LibraryCloudMediaRestoreService? createLibraryCloudMediaRestoreService(
  SupabaseClient client,
) {
  return platform.createLibraryCloudMediaRestoreService(client);
}
