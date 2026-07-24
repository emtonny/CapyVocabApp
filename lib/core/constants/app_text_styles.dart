// Font hệ: Fredoka (tiêu đề) + Nunito (nội dung)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading = GoogleFonts.fredoka(
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );

  static TextStyle body = GoogleFonts.nunito(
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );
}
