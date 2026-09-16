// FR-GAME2-01: điền chữ theo ảnh đồ vật
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/graph_paper_background.dart';

/// UI screen tương ứng FR-GAME2-01: điền chữ theo ảnh đồ vật
class PhotoLetterFillScreen extends StatelessWidget {
  const PhotoLetterFillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphPaperScaffold(
      body: Center(
        child: Text('PhotoLetterFillScreen'),
      ),
    );
  }
}
