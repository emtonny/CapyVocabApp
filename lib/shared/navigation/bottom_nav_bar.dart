import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

/// Map từ route path → chỉ số tab tương ứng
const _tabRoutes = ['/home', '/storage', '/pet-shop', '/friends'];

/// Thanh điều hướng chính với nút quét ảnh nổi ở giữa.
/// Active tab được xác định từ current location của GoRouter.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // Determine active tab index; default to 0 (home) for unknown routes.
    final activeIndex = _tabRoutes.indexOf(location).clamp(0, 3);

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
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.home_rounded,
                          label: 'Trang chủ',
                          isActive: activeIndex == 0,
                          onTap: () => context.go('/home'),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.photo_library_rounded,
                          label: 'Thư viện',
                          isActive: activeIndex == 1,
                          onTap: () => context.go('/storage'),
                        ),
                      ),
                      const SizedBox(width: 80),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.storefront_rounded,
                          label: 'Cửa hàng',
                          isActive: activeIndex == 2,
                          onTap: () => context.go('/pet-shop'),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.people_alt_rounded,
                          label: 'Bạn bè',
                          isActive: activeIndex == 3,
                          onTap: () => context.go('/friends'),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.duoBlue;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = isActive ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.duoBlue.withValues(alpha: 0.1),
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  isActive ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : EdgeInsets.zero,
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.duoBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
