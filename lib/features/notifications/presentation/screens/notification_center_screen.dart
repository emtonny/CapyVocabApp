// FR-NOTIF-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/graph_paper_background.dart';

/// UI screen tương ứng FR-NOTIF-01
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphPaperScaffold(
      body: Center(
        child: Text('NotificationCenterScreen'),
      ),
    );
  }
}
