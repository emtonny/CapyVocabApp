import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum ScanImageSource { gallery, camera }

class PickedScanImage {
  const PickedScanImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

abstract interface class ScanImagePicker {
  Future<PickedScanImage?> pick(ScanImageSource source);
}

class DeviceScanImagePicker implements ScanImagePicker {
  DeviceScanImagePicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<PickedScanImage?> pick(ScanImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source == ScanImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (image == null) return null;

    return PickedScanImage(
      bytes: await image.readAsBytes(),
      name: image.name,
    );
  }
}
