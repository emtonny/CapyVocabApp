import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Display-only streak summary. A streak is awarded by completing the daily
/// lesson, never by tapping this card.
class StreakFlameWidget extends StatelessWidget {
  const StreakFlameWidget({
    super.key,
    required this.streakDays,
    this.waitingForSync = false,
  });

  final int streakDays;
  final bool waitingForSync;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: waitingForSync
          ? 'Chuỗi $streakDays ngày, đang chờ đồng bộ'
          : 'Chuỗi $streakDays ngày',
      child: Container(
        key: const Key('home-streak-summary'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/fluent_fire_3d.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streakDays ngày liên tiếp',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    waitingForSync
                        ? 'Đã lưu trên máy · đang chờ đồng bộ'
                        : 'Hoàn thành bài ngày để nối chuỗi',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
