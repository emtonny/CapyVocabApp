import '../../application/library_photo_note_deletion_service.dart';
import 'library_managed_media_purger_factory_stub.dart'
    if (dart.library.io) 'library_managed_media_purger_factory_io.dart'
    if (dart.library.js_interop) 'library_managed_media_purger_factory_web.dart'
    as platform;

LibraryManagedMediaPurger? createLibraryManagedMediaPurger() =>
    platform.createLibraryManagedMediaPurger();
