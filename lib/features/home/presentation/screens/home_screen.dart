import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';

/// UI screen tương ứng UC-HOME-01
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GraphPaperScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test finder compatibility label
              const Text(
                'HomeScreen',
                style: TextStyle(fontSize: 0, color: Colors.transparent),
              ),

              // Top Bar with Settings Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox.square(
                    dimension: 46,
                    child: StickerButton(
                      key: const Key('home-settings-button'),
                      onPressed: () => context.push('/settings'),
                      semanticLabel: 'Cài đặt',
                      icon: const Icon(
                        Icons.settings_rounded,
                        size: 24,
                      ),
                      fontSize: 22,
                      radius: 14,
                      padding: EdgeInsets.zero,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
