import 'package:flutter/material.dart';

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
        color: selected ? const Color(0xFFFFD86B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF20251F), width: 2),
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}
