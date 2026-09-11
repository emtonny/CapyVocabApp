import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../../data/datasources/scan_result_local_datasource.dart';
import '../../data/services/scan_image_storage.dart';
import '../../data/services/scan_image_picker.dart';
import '../providers/scan_provider.dart';

class ScanFlowController {
  const ScanFlowController._();

  static Future<void> scanAndNavigate(
    BuildContext context,
    WidgetRef ref, {
    required String localPath,
    Uint8List? imageBytes,
    ScanImageSource captureSource = ScanImageSource.gallery,
    String templateId = 'standard',
  }) async {
    final record = await scan(
      context,
      ref,
      localPath: localPath,
      imageBytes: imageBytes,
      captureSource: captureSource,
      templateId: templateId,
    );
    if (record == null || !context.mounted) return;

    context.push('/scan-overlay', extra: record);
  }

  static Future<ScanResultRecord?> scan(
    BuildContext context,
    WidgetRef ref, {
    required String localPath,
    Uint8List? imageBytes,
    ScanImageSource captureSource = ScanImageSource.gallery,
    String templateId = 'standard',
  }) async {
    try {
      return await ref.read(scanProvider.notifier).scanImage(
            localPath,
            imageBytes: imageBytes,
            captureSource: captureSource,
            templateId: templateId,
          );
    } catch (error, stackTrace) {
      _logError('scan', error, stackTrace);
      if (!context.mounted) return null;

      final message = switch (error) {
        GeminiVisionException() => error.message,
        ScanImageStorageException() => error.message,
        _ => 'Đã có lỗi khi quét ảnh, vui lòng thử lại.',
      };
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không thể quét ảnh'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return null;
    }
  }

  static void _logError(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('AI scan failed during $stage: $error');
    debugPrintStack(
      label: 'AI scan $stage stack trace',
      stackTrace: stackTrace,
    );
  }
}
