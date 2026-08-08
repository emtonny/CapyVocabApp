// FR-FRND-01: xếp hạng tuần + danh sách bạn bè

import 'package:flutter/material.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';

/// UI screen tương ứng FR-FRND-01 — Bạn bè & Bảng xếp hạng
class FriendsLeaderboardScreen extends StatelessWidget {
  const FriendsLeaderboardScreen({super.key});

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
                    '🏆',
                    style: TextStyle(fontSize: 28),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Bạn bè & Xếp hạng',
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
            const SizedBox(height: 16),

            // Weekly leaderboard hint cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE8D5BC),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  children: [
                    Text('📅', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảng xếp hạng tuần',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3C2A21),
                          ),
                        ),
                        Text(
                          'Cập nhật mỗi thứ Hai',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E8F85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                        child: Text('👥', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Cộng đồng',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kết bạn, so sánh điểm số hàng tuần\nvà cùng nhau học từ vựng.',
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
