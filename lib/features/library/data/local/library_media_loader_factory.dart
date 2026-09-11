import '../../application/library_media_loader.dart';
import 'library_media_loader_factory_stub.dart'
    if (dart.library.io) 'library_media_loader_factory_io.dart' as platform;

LibraryMediaLoader createLibraryMediaLoader() {
  return platform.createLibraryMediaLoader();
}
