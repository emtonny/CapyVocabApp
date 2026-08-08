import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppTheme {
  AppTheme._();

  static final _noTransitionsTheme = PageTransitionsTheme(
    builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
      TargetPlatform.values,
      value: (_) => const _NoTransitionsBuilder(),
    ),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.duoGreen,
        scaffoldBackgroundColor: AppColors.creamyYuzu,
        pageTransitionsTheme: _noTransitionsTheme,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.duoGreen,
        scaffoldBackgroundColor: AppColors.darkBackground,
        pageTransitionsTheme: _noTransitionsTheme,
      );
}

