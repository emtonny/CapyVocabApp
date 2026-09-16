// FR-SOLO-02: 5 câu hỏi, đếm ngược 10s/câu
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/graph_paper_background.dart';

/// UI screen tương ứng FR-SOLO-02: 5 câu hỏi, đếm ngược 10s/câu
class SoloBattleScreen extends StatelessWidget {
  const SoloBattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphPaperScaffold(
      body: Center(
        child: Text('SoloBattleScreen'),
      ),
    );
  }
}
