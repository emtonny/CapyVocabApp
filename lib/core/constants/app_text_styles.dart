// Font hệ: Fredoka (tiêu đề) + Nunito (nội dung)
import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontFamily: 'Fredoka',
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );
}
