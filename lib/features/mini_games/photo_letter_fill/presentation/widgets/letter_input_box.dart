import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

/// Ô trình bày ký tự; nhập liệu thật vẫn do [TextField] của màn game quản lý.
class LetterInputBox extends StatelessWidget {
  const LetterInputBox({
    required this.character,
    this.active = false,
    super.key,
  });

  final String character;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.yellow : AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
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
        character,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
    );
  }
}
