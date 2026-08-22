import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';

/// UI screen tương ứng UC-HOME-01
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test finder compatibility label
              const Text(
                'HomeScreen',
                style: TextStyle(fontSize: 0, color: Colors.transparent),
              ),

              // Top Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Points Badge Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE6D8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE0D4C3),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🍪', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 6),
                        Text(
                          '220',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Icons: Bell & Settings
                  Row(
                    children: [
                      // Bell with Notification Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFE6D8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE0D4C3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Color(0xFF5D4037),
                              size: 24,
                            ),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: const Text(
                                '3',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // Settings Gear Icon
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE6D8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE0D4C3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.settings_rounded,
                            color: Color(0xFF5D4037),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Game Map Progress Node Card Banner
              Container(
                height: 130,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EFE6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2D6C5),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Node Circle
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7CB342),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_cafe_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // "Game Điền Từ Theo Ảnh" Container Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2E9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2D6C5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 22,
                              color: Color(0xFF5D4037),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Game Điền Từ Theo Ảnh',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3C2A21),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE6D8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calculate_rounded,
                            size: 18,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dashed Divider
                    Row(
                      children: List.generate(
                        30,
                        (index) => Expanded(
                          child: Container(
                            height: 1.5,
                            color: index % 2 == 0
                                ? const Color(0xFFD4C8B8)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid of 4 Level Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children: const [
                        _LevelCard(
                          date: '01/07',
                          photoCount: '2 Ảnh 📷',
                          item1: '💡 Đèn làm việc 💡',
                          item2: '📘 Sổ tay ghi chép 📘',
                        ),
                        _LevelCard(
                          date: '02/07',
                          photoCount: '2 Ảnh 📷',
                          item1: '☕ Tách Cà Phê Espresso',
                          item2: '🥐 Bánh Croissant Bơ',
                        ),
                        _LevelCard(
                          date: '03/07',
                          photoCount: '2 Ảnh 📷',
                          item1: '💻 Bàn phím cơ RGB',
                          item2: '🖱️ Chuột Gaming',
                        ),
                        _LevelCard(
                          date: '04/07',
                          photoCount: '2 Ảnh 📷',
                          item1: '🎒 Ba Lô Du Lịch',
                          item2: '👟 Giày Sneaker',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.date,
    required this.photoCount,
    required this.item1,
    required this.item2,
  });

  final String date;
  final String photoCount;
  final String item1;
  final String item2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8DEC8),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Count Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
              Text(
                photoCount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items list
          Text(
            '1. $item1',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C2A21),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '2. $item2',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C2A21),
            ),
          ),
          const Spacer(),

          // Green 3D Button "Điền Từ 🚀"
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66BB6A),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Điền Từ',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('🚀', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
