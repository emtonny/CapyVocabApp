import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

const softPageTransitionDuration = Duration(milliseconds: 280);
const softPageReverseTransitionDuration = Duration(milliseconds: 240);

Widget buildSoftPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return child;
  }

  final curvedAnimation = animation.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );

  return FadeTransition(
    opacity: curvedAnimation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.018),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    ),
  );
}

class _SoftTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildSoftPageTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class AppTheme {
  AppTheme._();

  static final _softTransitionsTheme = PageTransitionsTheme(
    builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
      TargetPlatform.values,
      value: (_) => const _SoftTransitionsBuilder(),
    ),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.nunito().fontFamily,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.duoGreen,
        scaffoldBackgroundColor: AppColors.creamyYuzu,
        pageTransitionsTheme: _softTransitionsTheme,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.nunito().fontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.duoGreen,
        scaffoldBackgroundColor: AppColors.darkBackground,
        pageTransitionsTheme: _softTransitionsTheme,
      );
}
