import 'package:flutter/material.dart';

/// Small in-app gold coin mark used beside balances and rewards.
class GoldCoinIcon extends StatelessWidget {
  const GoldCoinIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3A8),
              Color(0xFFFFD34D),
              Color(0xFFE3A000),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF986000),
            width: size * .06,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55805000),
              offset: Offset(0, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFC18400),
              width: size * .04,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.star_rounded,
              color: const Color(0xFF9A5D00),
              size: size * .46,
            ),
          ),
        ),
      ),
    );
  }
}
