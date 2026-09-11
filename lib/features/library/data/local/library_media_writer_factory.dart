import '../../application/library_cloud_media_restore_service.dart';
import 'library_media_writer_factory_stub.dart'
    if (dart.library.io) 'library_media_writer_factory_io.dart' as platform;

LibraryLocalMediaWriter? createLibraryLocalMediaWriter() {
  return platform.createLibraryLocalMediaWriter();
}
