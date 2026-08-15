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
    try {
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
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImagePickerException(
          source == ScanImageSource.camera
              ? 'Không thể mở camera. Vui lòng kiểm tra quyền truy cập.'
              : 'Không thể chọn ảnh. Vui lòng thử lại.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}

class ScanImagePickerException implements Exception {
  const ScanImagePickerException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final rootCause = cause;
    return rootCause == null
        ? 'ScanImagePickerException: $message'
        : 'ScanImagePickerException: $message Cause: $rootCause';
  }
}
