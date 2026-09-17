// Font dùng chung toàn ứng dụng: Nunito.
import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );
}
