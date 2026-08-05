import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/scan_result_local_datasource.dart';
import '../providers/scan_provider.dart';
import '../widgets/vocab_canvas_overlay.dart';

class ScanResultOverlayScreen extends ConsumerStatefulWidget {
  const ScanResultOverlayScreen({required this.record, super.key});

  final ScanResultRecord record;

  @override
  ConsumerState<ScanResultOverlayScreen> createState() =>
      _ScanResultOverlayScreenState();
}

class _ScanResultOverlayScreenState
    extends ConsumerState<ScanResultOverlayScreen> {
  late Future<Uint8List> _imageBytes;

  @override
  void initState() {
    super.initState();
    _imageBytes = _readImage();
  }

  @override
  void didUpdateWidget(covariant ScanResultOverlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.localPath != widget.record.localPath) {
      _imageBytes = _readImage();
    }
  }

  Future<Uint8List> _readImage() {
    return ref.read(scanImageStorageProvider).readBytes(
          widget.record.localPath,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả quét')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Uint8List>(
            future: _imageBytes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Không thể mở ảnh đã quét.'),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return VocabCanvasOverlay(
                imageProvider: MemoryImage(bytes),
                words: widget.record.result.words,
              );
            },
          ),
        ),
      ),
    );
  }
}
