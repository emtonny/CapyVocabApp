import '../../application/library_media_integrity_auditor.dart';
import '../../application/library_media_recovery_service.dart';
import 'library_media_inventory_factory_stub.dart'
    if (dart.library.io) 'library_media_inventory_factory_io.dart' as platform;

LibraryMediaInventory? createLibraryMediaInventory() {
  return platform.createLibraryMediaInventory();
}

LibraryMediaRecoveryStore? createLibraryMediaRecoveryStore() {
  return platform.createLibraryMediaRecoveryStore();
}
