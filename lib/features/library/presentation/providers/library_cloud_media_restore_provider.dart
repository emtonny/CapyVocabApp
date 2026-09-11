import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../application/library_cloud_media_restore_service.dart';
import '../../data/remote/library_sync_gateway_factory.dart';
import 'library_sync_provider.dart';

final libraryCloudMediaRestoreServiceProvider =
    Provider<LibraryCloudMediaRestoreService?>((ref) {
  if (!librarySyncEnabled) return null;
  return createLibraryCloudMediaRestoreService(SupabaseService.client);
});
