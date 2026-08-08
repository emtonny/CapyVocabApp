// FR-SHOP-01: 4 sub-tab (Linh Vật/Trang Phục/Hình Nền/Solo Item)

import 'package:flutter/material.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';

/// UI screen tương ứng FR-SHOP-01 — Cửa hàng & Pet Shop
class PetShopScreen extends StatelessWidget {
  const PetShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    '🛍️',
                    style: TextStyle(fontSize: 28),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Cửa hàng',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C2A21),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sub-tab hints
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ShopTabChip('🐾 Linh Vật'),
                  _ShopTabChip('👗 Trang Phục'),
                  _ShopTabChip('🖼️ Hình Nền'),
                  _ShopTabChip('⚔️ Solo Item'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Coming Soon Content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EFE6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2D6C5),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('🛒', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Cửa hàng',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Trang bị linh vật, trang phục và\ncác vật phẩm solo sắp ra mắt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9E8F85),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: const Text(
                        '🚧  Đang phát triển...',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class _ShopTabChip extends StatelessWidget {
  const _ShopTabChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2D6C5), width: 1.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5D4037),
        ),
      ),
    );
  }
}
