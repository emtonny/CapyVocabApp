import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../providers/scan_provider.dart';

class ScanFlowController {
  const ScanFlowController._();

  static Future<void> scanAndNavigate(
    BuildContext context,
    WidgetRef ref, {
    required String localPath,
  }) async {
    try {
      final record = await ref.read(scanProvider.notifier).scanImage(localPath);
      if (!context.mounted) return;

      context.push('/scan-overlay', extra: record);
    } catch (error) {
      if (!context.mounted) return;

      final message =
          error is GeminiVisionException ? error.message : 'Đã có lỗi, thử lại';
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
    }
  }
}
