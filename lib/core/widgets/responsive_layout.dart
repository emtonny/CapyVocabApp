import 'package:flutter/material.dart';

/// Standard breakpoint thresholds for responsive design
class ResponsiveBreakpoints {
  /// Width threshold below which layout is considered mobile (< 600px)
  static const double mobileMax = 600.0;

  /// Width threshold below which layout is considered tablet (< 1024px)
  static const double tabletMax = 1024.0;
}

/// Helper extension on BuildContext to quickly query responsive window traits
extension ResponsiveContextX on BuildContext {
  /// Returns width of current app window
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Returns height of current app window
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True if current window width is mobile (< 600px)
  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobileMax;

  /// True if current window width is tablet (600px - 1023px)
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.mobileMax &&
      screenWidth < ResponsiveBreakpoints.tabletMax;

  /// True if current window width is desktop (>= 1024px)
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.tabletMax;

  /// True if current window width is tablet or desktop (>= 600px)
  bool get isTabletOrDesktop => screenWidth >= ResponsiveBreakpoints.mobileMax;
}

/// Adaptive layout builder widget that switches widget tree based on available width constraints
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Widget to render on small/mobile screens (< 600px)
  final Widget mobile;

  /// Optional widget to render on tablet screens (600px - 1023px). Fallback: desktop or mobile.
  final Widget? tablet;

  /// Optional widget to render on large/desktop screens (>= 1024px). Fallback: tablet or mobile.
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= ResponsiveBreakpoints.tabletMax) {
          return desktop ?? tablet ?? mobile;
        }

        if (width >= ResponsiveBreakpoints.mobileMax) {
          return tablet ?? desktop ?? mobile;
        }

        return mobile;
      },
    );
  }
}
