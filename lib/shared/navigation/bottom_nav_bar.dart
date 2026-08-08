import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

/// Thanh điều hướng chính với nút quét ảnh nổi ở giữa.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              left: 0,
              child: Material(
                elevation: 8,
                color: colorScheme.surface,
                child: const SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.home_rounded,
                          label: 'Trang chủ',
                        ),
                      ),
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.photo_library_rounded,
                          label: 'Thư viện',
                        ),
                      ),
                      SizedBox(width: 80),
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.storefront_rounded,
                          label: 'Cửa hàng',
                        ),
                      ),
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.people_alt_rounded,
                          label: 'Bạn bè',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox.square(
              dimension: 68,
              child: FloatingActionButton(
                key: const Key('bottom-nav-camera-button'),
                heroTag: 'bottom-nav-camera-button',
                elevation: 8,
                backgroundColor: AppColors.duoBlue,
                foregroundColor: Colors.white,
                tooltip: 'Quét ảnh từ vựng',
                onPressed: () => context.push('/scan'),
                child: const Icon(Icons.photo_camera_rounded, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: false,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
