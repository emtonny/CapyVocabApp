import 'package:flutter/material.dart';

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
        color: active ? const Color(0xFFFFF1B8) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF20251F), width: 2),
      ),
      child: Text(
        character,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
    );
  }
}
