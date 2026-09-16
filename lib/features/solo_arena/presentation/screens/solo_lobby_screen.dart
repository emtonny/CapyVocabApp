// FR-SOLO-01: Lobby thách đấu + slider cược
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/graph_paper_background.dart';

/// UI screen tương ứng FR-SOLO-01: Lobby thách đấu + slider cược
class SoloLobbyScreen extends StatelessWidget {
  const SoloLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphPaperScaffold(
      body: Center(
        child: Text('SoloLobbyScreen'),
      ),
    );
  }
}
