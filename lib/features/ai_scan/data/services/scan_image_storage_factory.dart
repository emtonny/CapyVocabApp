import 'scan_image_storage.dart';
import 'scan_image_storage_memory.dart'
    if (dart.library.io) 'scan_image_storage_io.dart'
    if (dart.library.js_interop) 'scan_image_storage_web.dart' as platform;

ScanImageStorage createScanImageStorage() => platform.createScanImageStorage();
