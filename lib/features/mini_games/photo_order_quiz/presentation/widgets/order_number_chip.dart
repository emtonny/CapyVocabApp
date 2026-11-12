import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

/// Marker số có touch target tối thiểu 48 dp cho game ghép từ.
class OrderNumberChip extends StatelessWidget {
  const OrderNumberChip({
    required this.number,
    this.selected = false,
    super.key,
  });

  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.yellow : AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}
