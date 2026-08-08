import 'package:flutter/material.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';

/// UI screen tương ứng UC-HOME-01
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('HomeScreen'),
      ),
      bottomNavigationBar: BottomNavBar(),
    );
  }
}
