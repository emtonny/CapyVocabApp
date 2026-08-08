// FR-STOR-01, FR-STOR-02, UC-STOR-01

import 'package:flutter/material.dart';

import '../../../../shared/navigation/bottom_nav_bar.dart';

/// UI screen tương ứng FR-STOR-01 — Thư viện album scan
class StorageAlbumScreen extends StatelessWidget {
  const StorageAlbumScreen({super.key});

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
                    '📚',
                    style: TextStyle(fontSize: 28),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Thư viện của tôi',
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
                        child: Text('🗂️', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Thư viện',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tất cả album ảnh & từ vựng\nđã quét sẽ xuất hiện ở đây.',
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
