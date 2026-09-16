// FR-SOLO-03: tổng kết + cộng/trừ xu cược
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/graph_paper_background.dart';

/// UI screen tương ứng FR-SOLO-03: tổng kết + cộng/trừ xu cược
class SoloResultScreen extends StatelessWidget {
  const SoloResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphPaperScaffold(
      body: Center(
        child: Text('SoloResultScreen'),
      ),
    );
  }
}
