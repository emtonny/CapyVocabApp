import '../../application/library_photo_note_deletion_service.dart';
import 'library_web_media_blob_store.dart';

LibraryManagedMediaPurger createLibraryManagedMediaPurger() =>
    WebLibraryManagedMediaPurger();

final class WebLibraryManagedMediaPurger implements LibraryManagedMediaPurger {
  @override
  Future<void> deleteAll(Iterable<String> relativePaths) async {
    for (final relativePath in relativePaths.toSet()) {
      await libraryWebMediaBlobStore.delete(relativePath);
    }
  }
}
